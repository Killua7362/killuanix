#!/usr/bin/env python3
"""Broker client shim — installed on Claude's PATH INSIDE the bwrap sandbox only
(via overlayClaude's --setenv PATH in claude.nix). Behaviour is keyed on the
invoked name so one script serves two shims:

  pkexec      → kind="pkexec"   : forward `pkexec <cmd>` to the broker (root,
                                   GUI auth, runs unmasked, streams back).
  nix_switch  → kind="nixswitch": forward the mode/flags to the broker, which
                                   runs the real nix_switch AS YOU, unmasked,
                                   with pkexec escalation for the root step
                                   (GUI password). Makes `nix_switch both`
                                   work from inside the sandbox.

The user's own terminal is untouched — these shims live only on Claude's
sandbox PATH, so real `pkexec` / `nix_switch` still resolve normally there.

See broker.py for the wire framing.
"""
import json
import os
import shutil
import socket
import struct
import sys

SOCK = os.path.join(
    os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "claude-pkexec.sock"
)


def die(msg, code=127):
    sys.stderr.write(msg + "\n")
    sys.exit(code)


def recvn(sock, n):
    buf = b""
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            return None
        buf += chunk
    return buf


def main():
    name = os.path.basename(sys.argv[0])
    argv = sys.argv[1:]

    if name == "nix_switch":
        kind = "nixswitch"
        # argv is just mode/flags (both/home/system/...). Binary is fixed in
        # the broker; nothing to resolve here.
    else:
        kind = "pkexec"
        if not argv:
            die("pkexec (broker shim): usage: pkexec <command> [args...]", 2)
        # Resolve argv[0] to an absolute path using Claude's PATH — pkexec's
        # root PATH excludes /run/current-system/sw/bin and /nix/store.
        prog = argv[0]
        if not prog.startswith("/"):
            found = shutil.which(prog)
            if found:
                argv = [found, *argv[1:]]

    try:
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.connect(SOCK)
    except (FileNotFoundError, ConnectionRefusedError):
        die(
            "%s (broker shim): pkexec-broker not running — cannot run this from "
            "inside the sandbox. Start it: systemctl --user start pkexec-broker"
            % name,
            127,
        )

    req = json.dumps({"kind": kind, "argv": argv, "cwd": os.getcwd()}).encode()
    sock.sendall(struct.pack(">I", len(req)) + req)

    exit_code = 1
    while True:
        hdr = recvn(sock, 5)
        if not hdr:
            break
        tag = hdr[0:1]
        (length,) = struct.unpack(">I", hdr[1:5])
        payload = recvn(sock, length) if length else b""
        if payload is None:
            break
        if tag == b"O":
            sys.stdout.buffer.write(payload)
            sys.stdout.buffer.flush()
        elif tag == b"E":
            sys.stderr.buffer.write(payload)
            sys.stderr.buffer.flush()
        elif tag == b"X":
            try:
                exit_code = int(payload.decode() or "1")
            except ValueError:
                exit_code = 1
            break

    sys.exit(exit_code)


if __name__ == "__main__":
    main()
