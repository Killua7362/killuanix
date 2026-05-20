#!@python3@/bin/python3
"""Boeing VPN browser-UI daemon.

Bridges a small HTTP/JSON API on 127.0.0.1:7777 to the openconnect +
ocproxy command pair used by the `boeingvpn` zsh function. Serves a
static HTML/JS frontend from the same port so a bookmark like
http://127.0.0.1:7777/ Just Works inside chrome-socks.

Substituted at build time by pkgs.replaceVars:
  python3     -- python interpreter store path
  openconnect -- openconnect store path (bin dir on PATH)
  ocproxy     -- ocproxy store path (bin dir on PATH)
  static      -- directory containing index.html, style.css, app.js, wallpaper.svg
"""

import json
import mimetypes
import os
import signal
import socket
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import shutil

def _resolve(placeholder: str, env_var: str, bin_name: str | None) -> str:
    """Allow `python3 daemon.py` from a worktree to skip the nix substitution.

    Priority: env var > nix-substituted store path > PATH lookup. Lets the
    daemon run unmodified out of a checkout while still being deterministic
    in the systemd unit.
    """
    override = os.environ.get(env_var)
    if override:
        return override
    if not placeholder.startswith("@"):
        return placeholder
    if bin_name:
        found = shutil.which(bin_name)
        if found:
            return found
    raise SystemExit(f"daemon.py not nix-built and ${env_var} unset; cannot resolve {placeholder}")


OPENCONNECT = _resolve("@openconnect@/bin/openconnect", "BOEINGVPN_OPENCONNECT", "openconnect")
OCPROXY = _resolve("@ocproxy@/bin/ocproxy", "BOEINGVPN_OCPROXY", "ocproxy")
_STATIC = os.environ.get("BOEINGVPN_STATIC") or "@static@"
if _STATIC.startswith("@"):
    _STATIC = str(Path(__file__).resolve().parent / "static")
STATIC_DIR = Path(_STATIC)

VPN_HOST = "https://ta.as2.cbc.vpn.boeing.net"
VPN_USER = "dj216f"
VPN_GROUP = "gateway"
SOCKS_PORT = 1080

BIND_HOST = "127.0.0.1"
BIND_PORT = 7777


class VpnManager:
    """Owns the openconnect child process and mirrors its lifecycle as state."""

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._proc: subprocess.Popen | None = None
        self._state: str = "idle"
        self._last_error: str = ""
        self._started_at: float | None = None
        self._last_secret: str | None = None
        self._stderr_tail: list[str] = []

    def snapshot(self) -> dict:
        with self._lock:
            return {
                "state": self._state,
                "started_at": self._started_at,
                "last_error": self._last_error,
                "pid": self._proc.pid if self._proc and self._proc.poll() is None else None,
            }

    def connect(self, secret: str) -> tuple[bool, str]:
        with self._lock:
            if self._proc and self._proc.poll() is None:
                return False, "already running"

            # Ocproxy must be reachable via PATH for openconnect's --script.
            env = os.environ.copy()
            env["PATH"] = f"{os.path.dirname(OCPROXY)}:{env.get('PATH', '')}"

            try:
                self._proc = subprocess.Popen(
                    [
                        OPENCONNECT,
                        "--protocol=gp",
                        f"--user={VPN_USER}",
                        f"--usergroup={VPN_GROUP}",
                        "--script-tun",
                        "--script",
                        f"ocproxy -D {SOCKS_PORT}",
                        "--passwd-on-stdin",
                        VPN_HOST,
                    ],
                    stdin=subprocess.PIPE,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.PIPE,
                    env=env,
                    start_new_session=True,
                )
            except FileNotFoundError as exc:
                self._state = "error"
                self._last_error = f"spawn failed: {exc}"
                return False, self._last_error

            assert self._proc.stdin is not None
            try:
                self._proc.stdin.write((secret + "\n").encode())
                self._proc.stdin.flush()
                self._proc.stdin.close()
            except BrokenPipeError:
                pass

            self._state = "connecting"
            self._started_at = time.time()
            self._last_error = ""
            self._last_secret = secret
            self._stderr_tail = []

        threading.Thread(target=self._watch, daemon=True).start()
        threading.Thread(target=self._poll_socks, daemon=True).start()
        return True, "spawned"

    def disconnect(self) -> tuple[bool, str]:
        with self._lock:
            proc = self._proc
            if not proc or proc.poll() is not None:
                self._state = "idle"
                return True, "already stopped"
            self._state = "disconnecting"

        try:
            os.killpg(proc.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass

        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(proc.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            proc.wait(timeout=2)

        with self._lock:
            self._state = "idle"
            self._started_at = None
            self._proc = None
        return True, "stopped"

    def reconnect(self) -> tuple[bool, str]:
        secret = self._last_secret
        if not secret:
            return False, "no cached secret; click Connect"
        self.disconnect()
        return self.connect(secret)

    def _watch(self) -> None:
        proc = self._proc
        if proc is None or proc.stderr is None:
            return

        for raw in iter(proc.stderr.readline, b""):
            line = raw.decode(errors="replace").rstrip()
            if not line:
                continue
            # Surface openconnect progress to journalctl for debugging.
            print(f"openconnect: {line}", file=sys.stderr, flush=True)
            with self._lock:
                self._stderr_tail.append(line)
                if len(self._stderr_tail) > 50:
                    self._stderr_tail = self._stderr_tail[-50:]
                if self._state == "connecting" and "Connected as" in line:
                    self._state = "connected"

        rc = proc.wait()
        with self._lock:
            if rc == 0:
                self._state = "idle"
            else:
                self._state = "error"
                tail = " | ".join(self._stderr_tail[-3:]) if self._stderr_tail else f"exit {rc}"
                self._last_error = tail
            self._started_at = None
            self._proc = None

    def _poll_socks(self) -> None:
        """Authoritative connect signal: ocproxy listening on SOCKS_PORT.

        openconnect's "Connected as" stderr line is version/protocol dependent;
        the SOCKS listener appearing is a direct proof the tunnel is usable.
        """
        proc = self._proc
        deadline = time.time() + 60
        while proc is not None and proc.poll() is None and time.time() < deadline:
            with self._lock:
                if self._state not in ("connecting", "connected"):
                    return
                if self._state == "connected":
                    return
            try:
                with socket.create_connection(("127.0.0.1", SOCKS_PORT), timeout=0.5):
                    pass
                with self._lock:
                    if self._state == "connecting":
                        self._state = "connected"
                        print(
                            f"boeingvpn-ui: SOCKS listener up on :{SOCKS_PORT}, state=connected",
                            file=sys.stderr,
                            flush=True,
                        )
                return
            except (OSError, ConnectionRefusedError):
                time.sleep(0.5)


VPN = VpnManager()


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt: str, *args) -> None:  # noqa: A003
        sys.stderr.write("[%s] %s\n" % (self.log_date_time_string(), fmt % args))

    def _json(self, code: int, payload: dict) -> None:
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _serve_static(self, rel: str) -> None:
        if rel == "" or rel == "/":
            rel = "index.html"
        target = (STATIC_DIR / rel.lstrip("/")).resolve()
        try:
            target.relative_to(STATIC_DIR.resolve())
        except ValueError:
            self.send_error(403)
            return
        if not target.is_file():
            self.send_error(404)
            return
        ctype, _ = mimetypes.guess_type(str(target))
        data = target.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", ctype or "application/octet-stream")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self) -> None:  # noqa: N802
        if self.path == "/api/status":
            self._json(200, VPN.snapshot())
            return
        self._serve_static(self.path)

    def do_POST(self) -> None:  # noqa: N802
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length) if length else b""
        try:
            payload = json.loads(raw) if raw else {}
        except json.JSONDecodeError:
            self._json(400, {"ok": False, "error": "invalid json"})
            return

        if self.path == "/api/connect":
            secret = (payload.get("secret") or "").strip()
            if not secret:
                self._json(400, {"ok": False, "error": "missing secret"})
                return
            ok, msg = VPN.connect(secret)
            self._json(200 if ok else 409, {"ok": ok, "msg": msg, **VPN.snapshot()})
            return
        if self.path == "/api/disconnect":
            ok, msg = VPN.disconnect()
            self._json(200 if ok else 500, {"ok": ok, "msg": msg, **VPN.snapshot()})
            return
        if self.path == "/api/reconnect":
            ok, msg = VPN.reconnect()
            self._json(200 if ok else 409, {"ok": ok, "msg": msg, **VPN.snapshot()})
            return

        self.send_error(404)


def main() -> int:
    for binary in (OPENCONNECT, OCPROXY):
        if not Path(binary).is_file():
            print(f"missing binary: {binary}", file=sys.stderr)
            return 1
    if not STATIC_DIR.is_dir():
        print(f"missing static dir: {STATIC_DIR}", file=sys.stderr)
        return 1

    server = ThreadingHTTPServer((BIND_HOST, BIND_PORT), Handler)
    print(f"boeingvpn-ui listening on http://{BIND_HOST}:{BIND_PORT}", file=sys.stderr)

    def _shutdown(*_a):
        # server.shutdown() blocks until serve_forever returns, so it must run
        # off the signal-handling main thread or we deadlock.
        threading.Thread(target=lambda: (VPN.disconnect(), server.shutdown()), daemon=True).start()

    signal.signal(signal.SIGTERM, _shutdown)
    signal.signal(signal.SIGINT, _shutdown)

    try:
        server.serve_forever()
    finally:
        VPN.disconnect()
    return 0


if __name__ == "__main__":
    sys.exit(main())
