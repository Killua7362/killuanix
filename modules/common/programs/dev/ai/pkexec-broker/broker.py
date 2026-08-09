#!/usr/bin/env python3
"""pkexec-broker — run privileged / unmasked commands OUTSIDE Claude's sandbox.

Claude Code runs under bwrap (see overlayClaude in claude.nix), which masks the
secret dirs (~/killuanix/secrets, ~/.config/sops/age) from claude and every
child it spawns. Commands that need those dirs (nixos-rebuild's sops decrypt)
would see them empty. This broker runs in the user's *graphical session* (a
systemd --user service, NOT under bwrap), so its children run in the host
namespace with the secret dirs VISIBLE, and hyprpolkitagent shows the GUI
password dialog (password flows agent→polkitd only — never on disk / into
Claude). stdout/stderr/exit stream back to the client shim in the sandbox.

Two request kinds (from client.py, chosen by the shim's invoked name):

  kind="pkexec"   → run `pkexec <argv>` (root, GUI auth). Any command. This is
                    the generic elevate path (`pkexec` shim).
  kind="nixswitch"→ run the ALLOWLISTED real nix_switch AS THE USER (not root),
                    forced `--no-nh`, with NIX_SWITCH_ESCALATE=pkexec so its
                    internal root step pops the polkit GUI. Runs unmasked, so
                    the home half sees the age key and the system half's
                    `pkexec nixos-rebuild` decrypts sops. argv = the mode/flags
                    (e.g. ["both"]); the binary is fixed (@nixswitch@) — the
                    client can't substitute it. This is deliberately the only
                    "run-as-you-unmasked" path (else it'd be an unmask escape).

Wire framing (length-prefixed, big-endian):
  request : 4-byte len + JSON {"kind": "...", "argv": [...], "cwd": "..."}
  response: repeated frames = 1 type byte + 4-byte len + payload
            'O' = stdout, 'E' = stderr, 'X' = exit code (ASCII int, final).

Security: socket is mode 0600 in $XDG_RUNTIME_DIR (0700) — same-uid only. The
broker never auto-approves: pkexec/nixos-rebuild always hit a GUI dialog the
user approves. Token-bucket rate limit blunts dialog-spam.
"""
import collections
import json
import os
import socket
import struct
import subprocess
import sys
import threading
import time

PKEXEC = "@pkexec@"  # nix-substituted setuid pkexec wrapper
NIXSWITCH = "@nixswitch@"  # nix-substituted absolute path to the real nix_switch
SOCK = os.path.join(
    os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "claude-pkexec.sock"
)

# Full PATH for the nix_switch child (systemd --user PATH can be minimal).
_NS_PATH = ":".join(
    [
        "/run/wrappers/bin",
        "/run/current-system/sw/bin",
        os.path.expanduser("~/.nix-profile/bin"),
    ]
)

REQS = 12
WINDOW = 60
_events = collections.deque()
_rl_lock = threading.Lock()


def log(*args):
    print("[pkexec-broker]", *args, file=sys.stderr, flush=True)


def rate_ok():
    now = time.monotonic()
    with _rl_lock:
        while _events and now - _events[0] > WINDOW:
            _events.popleft()
        if len(_events) >= REQS:
            return False
        _events.append(now)
        return True


def send_frame(conn, tag, payload):
    conn.sendall(tag + struct.pack(">I", len(payload)) + payload)


def recvn(conn, n):
    buf = b""
    while len(buf) < n:
        chunk = conn.recv(n - len(buf))
        if not chunk:
            return None
        buf += chunk
    return buf


def build(kind, argv):
    """Return (cmd list, env or None, empty_ok) for the request kind."""
    if kind == "nixswitch":
        env = dict(os.environ)
        env["PATH"] = _NS_PATH + ":" + env.get("PATH", "")
        env["NIX_SWITCH_ESCALATE"] = "pkexec"
        # Fixed binary + forced --no-nh; argv is only mode/flags.
        return ([NIXSWITCH, "--no-nh", *argv], env, True)
    # default: generic pkexec elevate
    return ([PKEXEC, *argv], None, False)


def handle(conn):
    try:
        hdr = recvn(conn, 4)
        if not hdr:
            return
        (length,) = struct.unpack(">I", hdr)
        body = recvn(conn, length)
        if body is None:
            return
        req = json.loads(body.decode())
        kind = req.get("kind") or "pkexec"
        argv = req.get("argv") or []
        cwd = req.get("cwd") or os.path.expanduser("~")

        cmd, env, empty_ok = build(kind, argv)
        if not argv and not empty_ok:
            send_frame(conn, b"E", b"pkexec-broker: empty command\n")
            send_frame(conn, b"X", b"2")
            return
        if not rate_ok():
            send_frame(
                conn,
                b"E",
                b"pkexec-broker: rate limit exceeded, wait a moment\n",
            )
            send_frame(conn, b"X", b"126")
            return

        run_cwd = cwd if os.path.isdir(cwd) else os.path.expanduser("~")
        log("%s:" % kind, " ".join(cmd), "(cwd=%s)" % run_cwd)
        try:
            proc = subprocess.Popen(
                cmd,
                cwd=run_cwd,
                env=env,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
        except Exception as exc:  # noqa: BLE001
            send_frame(
                conn, b"E", ("pkexec-broker: spawn failed: %s\n" % exc).encode()
            )
            send_frame(conn, b"X", b"127")
            return

        def pump(stream, tag):
            for chunk in iter(lambda: stream.read(4096), b""):
                try:
                    send_frame(conn, tag, chunk)
                except Exception:  # noqa: BLE001
                    break

        t_out = threading.Thread(target=pump, args=(proc.stdout, b"O"))
        t_err = threading.Thread(target=pump, args=(proc.stderr, b"E"))
        t_out.start()
        t_err.start()
        rc = proc.wait()
        t_out.join()
        t_err.join()
        send_frame(conn, b"X", str(rc).encode())
        log("exit:", rc)
    except Exception as exc:  # noqa: BLE001
        try:
            send_frame(conn, b"E", ("pkexec-broker: %s\n" % exc).encode())
            send_frame(conn, b"X", b"1")
        except Exception:  # noqa: BLE001
            pass
    finally:
        try:
            conn.close()
        except Exception:  # noqa: BLE001
            pass


def main():
    try:
        os.unlink(SOCK)
    except FileNotFoundError:
        pass
    srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    old_umask = os.umask(0o077)
    srv.bind(SOCK)
    os.umask(old_umask)
    os.chmod(SOCK, 0o600)
    srv.listen(8)
    log("listening on", SOCK)
    while True:
        conn, _ = srv.accept()
        threading.Thread(target=handle, args=(conn,), daemon=True).start()


if __name__ == "__main__":
    main()
