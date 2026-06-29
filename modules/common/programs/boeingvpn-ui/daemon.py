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
  useridfile  -- sops-decrypted file holding the default userid (boeing/vpn_userid)
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

# Gateway catalog (name, host). Single source of truth for the dropdown
# (served via /api/config) and the fastest-probe (/api/fastest).
GATEWAYS = [
    ("Amsterdam E", "ta.eu1.cbc.vpn.boeing.net"),
    ("Amsterdam F", "ta.eu2.cbc.vpn.boeing.net"),
    ("Brisbane E", "ta.au1.cbc.vpn.boeing.net"),
    ("Melbourne E", "ta.au2.cbc.vpn.boeing.net"),
    ("Northwest E", "ta.nw1.cbc.vpn.boeing.net"),
    ("Northwest F", "ta.nw2.cbc.vpn.boeing.net"),
    ("Southeast 1", "ta.se1.cbc.vpn.boeing.net"),
    ("Southeast 2", "ta.se2.cbc.vpn.boeing.net"),
    ("Southwest E", "ta.sw1.cbc.vpn.boeing.net"),
    ("Southwest F", "ta.sw2.cbc.vpn.boeing.net"),
    ("Tokyo E", "ta.as1.cbc.vpn.boeing.net"),
    ("Tokyo F", "ta.as2.cbc.vpn.boeing.net"),
]
GATEWAY_HOSTS = {host for _name, host in GATEWAYS}
DEFAULT_HOST = GATEWAYS[0][1]

VPN_GROUP = "gateway"
SOCKS_PORT = 1080

# Default userid: sops-decrypted file (path substituted at build time, or
# BOEINGVPN_USERID_FILE for worktree runs). Empty if neither present — the UI
# then requires the user to type one.
_USERID_FILE = os.environ.get("BOEINGVPN_USERID_FILE") or "@useridfile@"
if _USERID_FILE.startswith("@"):
    _USERID_FILE = ""


def default_userid() -> str:
    if _USERID_FILE:
        try:
            return Path(_USERID_FILE).read_text().strip()
        except OSError:
            pass
    return ""


# Number of TCP-connect samples per gateway; the median is taken so a single
# slow handshake (DNS warmup, transient loss) can't crown a loser.
PROBE_SAMPLES = 5
# Per-connect timeout (s). A down gateway costs at most this once, not ×SAMPLES,
# because probe_host bails after the first failed sample.
PROBE_TIMEOUT = 2.0
# Hard wall-clock cap (s) for an entire rank_gateways() sweep. Gateways still
# probing when it elapses are treated as unreachable for this run.
RANK_DEADLINE = 8.0


def _probe_once(host: str, port: int = 443, timeout: float = PROBE_TIMEOUT) -> float | None:
    """One TCP-connect RTT to host:port in ms, or None if unreachable.

    TLS is skipped on purpose: Boeing GP gateways require unsafe legacy
    renegotiation that modern TLS stacks refuse, so the TCP handshake time is
    the clean latency signal.
    """
    t0 = time.monotonic()
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return (time.monotonic() - t0) * 1000.0
    except OSError:
        return None


def probe_host(host: str, samples: int = PROBE_SAMPLES) -> float | None:
    """Median TCP-connect RTT over `samples` attempts, or None if all fail.

    2-strike early-exit: bail only after two leading failures with no success
    yet — a down host then costs ~2×timeout instead of samples×timeout. We don't
    bail on the *first* failure because the cold sample (DNS warmup) can exceed
    PROBE_TIMEOUT on a healthy gateway; the second, warm attempt succeeds.
    """
    from statistics import median

    vals: list[float] = []
    for i in range(samples):
        ms = _probe_once(host)
        if ms is None:
            if not vals and i >= 1:
                break
            continue
        vals.append(ms)
    return median(vals) if vals else None


def rank_gateways() -> list[dict]:
    """Probe all gateways concurrently, return reachable ones sorted fastest-first.

    Each gateway's samples run sequentially inside its own worker (so we don't
    measure self-induced contention), but the gateways are probed in parallel.
    A hard RANK_DEADLINE caps the whole sweep — stragglers are dropped.
    """
    from concurrent.futures import ThreadPoolExecutor, as_completed

    ranked: list[dict] = []
    # Not a `with` block: the executor's context-manager exit calls
    # shutdown(wait=True), which blocks on any still-running probe and would
    # blow past RANK_DEADLINE. We shut down with wait=False so the sweep RETURNS
    # at the deadline; stragglers finish (bounded by PROBE_TIMEOUT) and the pool
    # is GC'd.
    pool = ThreadPoolExecutor(max_workers=len(GATEWAYS))
    futures = {pool.submit(probe_host, host): (name, host) for name, host in GATEWAYS}
    try:
        for fut in as_completed(futures, timeout=RANK_DEADLINE):
            name, host = futures[fut]
            ms = fut.result()
            if ms is not None:
                ranked.append({"name": name, "host": host, "ms": round(ms, 1)})
    except TimeoutError:
        print(
            f"boeingvpn-ui: rank deadline {RANK_DEADLINE}s hit, "
            f"{len(ranked)}/{len(GATEWAYS)} gateways measured",
            file=sys.stderr,
            flush=True,
        )
    finally:
        pool.shutdown(wait=False, cancel_futures=True)
    ranked.sort(key=lambda r: r["ms"])
    return ranked


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
        self._last_userid: str | None = None
        self._last_gateway: str | None = None
        self._stderr_tail: list[str] = []

    def snapshot(self) -> dict:
        with self._lock:
            return {
                "state": self._state,
                "started_at": self._started_at,
                "last_error": self._last_error,
                "userid": self._last_userid,
                "gateway": self._last_gateway,
                "pid": self._proc.pid if self._proc and self._proc.poll() is None else None,
            }

    def connect(self, secret: str, userid: str, gateway: str) -> tuple[bool, str]:
        if not userid:
            return False, "missing userid"
        if gateway not in GATEWAY_HOSTS:
            return False, f"unknown gateway: {gateway}"
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
                        f"--user={userid}",
                        f"--usergroup={VPN_GROUP}",
                        "--script-tun",
                        "--script",
                        f"ocproxy -D {SOCKS_PORT}",
                        "--passwd-on-stdin",
                        f"https://{gateway}",
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
            self._last_userid = userid
            self._last_gateway = gateway
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
        userid = self._last_userid
        gateway = self._last_gateway
        if not secret or not userid or not gateway:
            return False, "no cached session; click Connect"
        self.disconnect()
        return self.connect(secret, userid, gateway)

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
        if self.path == "/api/config":
            self._json(200, {
                "default_userid": default_userid(),
                "gateways": [{"name": n, "host": h} for n, h in GATEWAYS],
            })
            return
        if self.path == "/api/fastest":
            ranked = rank_gateways()
            if not ranked:
                self._json(503, {"ok": False, "error": "no gateway reachable"})
                return
            self._json(200, {"ok": True, "fastest": ranked[0], "ranking": ranked})
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
            userid = (payload.get("userid") or "").strip() or default_userid()
            gateway = (payload.get("gateway") or "").strip()
            if not secret:
                self._json(400, {"ok": False, "error": "missing secret"})
                return
            if not userid:
                self._json(400, {"ok": False, "error": "missing userid"})
                return
            # gateway == "auto" → probe and pick the fastest now.
            if gateway == "auto" or not gateway:
                ranked = rank_gateways()
                if not ranked:
                    self._json(503, {"ok": False, "error": "no gateway reachable"})
                    return
                gateway = ranked[0]["host"]
            ok, msg = VPN.connect(secret, userid, gateway)
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
