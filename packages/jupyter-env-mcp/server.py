"""
Jupyter Env MCP Server.

Provisions per-name Python environments with uv, registers them as Jupyter
kernels, and owns the lifecycle of a single shared JupyterLab instance.

Pairs with the `jupyter` MCP server (datalayer/jupyter-mcp-server) which reads
JUPYTER_URL / JUPYTER_TOKEN from the runtime config file written by
`start_jupyter` here.
"""

from __future__ import annotations

import json
import os
import secrets
import shutil
import signal
import socket
import subprocess
import time
from pathlib import Path
from typing import Any

import httpx
from mcp.server.fastmcp import FastMCP

# ── Paths ─────────────────────────────────────────────────────────────────

HOME = Path.home()
ENVS_DIR = HOME / ".local" / "share" / "jupyter-mcp" / "envs"
NOTEBOOKS_DIR = HOME / "notebooks"
RUNTIME_DIR = HOME / ".cache" / "jupyter-mcp"
SERVER_JSON = RUNTIME_DIR / "server.json"
JUPYTER_LOG = RUNTIME_DIR / "jupyter.log"

# Tools the env-mcp shells out to. Resolved against PATH at call time so the
# Nix wrapper can inject them via runtimeInputs without baking store paths in.
UV = "uv"
JUPYTER = "jupyter"
XDG_OPEN = "xdg-open"


def _ensure_dirs() -> None:
    ENVS_DIR.mkdir(parents=True, exist_ok=True)
    NOTEBOOKS_DIR.mkdir(parents=True, exist_ok=True)
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)


def _env_dir(name: str) -> Path:
    if not name or "/" in name or name.startswith("."):
        raise ValueError(f"invalid env name: {name!r}")
    return ENVS_DIR / name


def _env_python(name: str) -> Path:
    return _env_dir(name) / "bin" / "python"


def _run(cmd: list[str], **kwargs: Any) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        check=False,
        capture_output=True,
        text=True,
        **kwargs,
    )


def _check(proc: subprocess.CompletedProcess[str], action: str) -> None:
    if proc.returncode != 0:
        raise RuntimeError(
            f"{action} failed (exit {proc.returncode}):\n"
            f"stdout: {proc.stdout.strip()}\n"
            f"stderr: {proc.stderr.strip()}"
        )


def _pid_alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except (OSError, ProcessLookupError):
        return False
    return True


def _free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def _read_server_json() -> dict[str, Any] | None:
    if not SERVER_JSON.exists():
        return None
    try:
        return json.loads(SERVER_JSON.read_text())
    except (OSError, json.JSONDecodeError):
        return None


# ── MCP server ────────────────────────────────────────────────────────────

mcp = FastMCP("jupyter-env")


@mcp.tool()
def create_env(name: str, packages: list[str] | None = None, python: str = "3.12") -> dict[str, Any]:
    """
    Create a new Python environment with uv and register it as a Jupyter kernel.

    Args:
        name: Env identifier. Becomes the kernel name and dir name.
        packages: Extra PyPI packages to install. ipykernel is always added.
        python: Python version spec passed to `uv venv --python`.
    """
    _ensure_dirs()
    env_dir = _env_dir(name)
    if env_dir.exists():
        raise RuntimeError(f"env {name!r} already exists at {env_dir}")

    _check(_run([UV, "venv", "--python", python, str(env_dir)]), "uv venv")

    pkgs = ["ipykernel", *(packages or [])]
    _check(
        _run(
            [UV, "pip", "install", "--python", str(_env_python(name)), *pkgs],
        ),
        "uv pip install",
    )

    _check(
        _run(
            [
                str(_env_python(name)),
                "-m",
                "ipykernel",
                "install",
                "--user",
                "--name",
                name,
                "--display-name",
                f"Python ({name})",
            ]
        ),
        "ipykernel install",
    )

    return {
        "name": name,
        "path": str(env_dir),
        "python": str(_env_python(name)),
        "installed": pkgs,
    }


@mcp.tool()
def list_envs() -> dict[str, Any]:
    """List all uv-managed envs and registered Jupyter kernels."""
    _ensure_dirs()
    envs = sorted(p.name for p in ENVS_DIR.iterdir() if (p / "bin" / "python").exists())

    kernels: dict[str, Any] = {}
    proc = _run([JUPYTER, "kernelspec", "list", "--json"])
    if proc.returncode == 0:
        try:
            kernels = json.loads(proc.stdout).get("kernelspecs", {})
        except json.JSONDecodeError:
            kernels = {}

    return {"envs": envs, "kernels": sorted(kernels.keys())}


@mcp.tool()
def install_packages(env: str, packages: list[str]) -> dict[str, Any]:
    """Install additional packages into an existing env."""
    if not packages:
        raise ValueError("packages must be non-empty")
    py = _env_python(env)
    if not py.exists():
        raise RuntimeError(f"env {env!r} not found at {_env_dir(env)}")
    _check(
        _run([UV, "pip", "install", "--python", str(py), *packages]),
        "uv pip install",
    )
    return {"env": env, "installed": packages}


@mcp.tool()
def delete_env(name: str) -> dict[str, Any]:
    """Delete an env's files and unregister its Jupyter kernel."""
    env_dir = _env_dir(name)
    if not env_dir.exists():
        raise RuntimeError(f"env {name!r} not found at {env_dir}")

    shutil.rmtree(env_dir)
    _run([JUPYTER, "kernelspec", "uninstall", "-y", name])
    return {"name": name, "deleted": True}


@mcp.tool()
def start_jupyter(notebook_dir: str = "", open_browser: bool = True) -> dict[str, Any]:
    """
    Start (or return existing) JupyterLab. Writes ~/.cache/jupyter-mcp/server.json
    with {url, token, port, pid} that the `jupyter` MCP wrapper reads.

    Args:
        notebook_dir: Root directory for notebooks. Defaults to ~/notebooks.
        open_browser: If true, xdg-open the tokenized URL.
    """
    _ensure_dirs()
    nb_dir = Path(notebook_dir).expanduser() if notebook_dir else NOTEBOOKS_DIR
    nb_dir.mkdir(parents=True, exist_ok=True)

    existing = _read_server_json()
    if existing and _pid_alive(existing.get("pid", -1)):
        if open_browser:
            subprocess.Popen([XDG_OPEN, _tokenized_url(existing)], start_new_session=True)
        return {"status": "already_running", **existing}

    if existing:
        SERVER_JSON.unlink(missing_ok=True)

    port = _free_port()
    token = secrets.token_urlsafe(32)
    log_fh = JUPYTER_LOG.open("ab")
    proc = subprocess.Popen(
        [
            JUPYTER,
            "lab",
            "--no-browser",
            f"--ServerApp.token={token}",
            "--ServerApp.password=",
            f"--ServerApp.root_dir={nb_dir}",
            f"--ServerApp.port={port}",
            "--ServerApp.allow_origin=*",
            "--ServerApp.disable_check_xsrf=True",
        ],
        stdout=log_fh,
        stderr=subprocess.STDOUT,
        start_new_session=True,
    )

    base_url = f"http://127.0.0.1:{port}"
    deadline = time.monotonic() + 30.0
    last_err: Exception | None = None
    while time.monotonic() < deadline:
        if proc.poll() is not None:
            raise RuntimeError(
                f"jupyter exited early (code {proc.returncode}); see {JUPYTER_LOG}"
            )
        try:
            r = httpx.get(f"{base_url}/api/status", params={"token": token}, timeout=2.0)
            if r.status_code == 200:
                last_err = None
                break
        except httpx.HTTPError as e:
            last_err = e
        time.sleep(0.4)
    else:
        proc.terminate()
        raise RuntimeError(f"jupyter failed to become healthy in 30s: {last_err}")

    info = {
        "url": base_url,
        "token": token,
        "port": port,
        "pid": proc.pid,
        "notebook_dir": str(nb_dir),
        "started_at": int(time.time()),
    }
    SERVER_JSON.write_text(json.dumps(info, indent=2))

    if open_browser:
        subprocess.Popen([XDG_OPEN, _tokenized_url(info)], start_new_session=True)

    return {"status": "started", **info}


def _tokenized_url(info: dict[str, Any]) -> str:
    return f"{info['url']}/lab?token={info['token']}"


@mcp.tool()
def stop_jupyter() -> dict[str, Any]:
    """Stop the JupyterLab instance owned by start_jupyter."""
    info = _read_server_json()
    if not info:
        return {"status": "not_running"}

    pid = info.get("pid", -1)
    if _pid_alive(pid):
        try:
            os.killpg(os.getpgid(pid), signal.SIGTERM)
        except (OSError, ProcessLookupError):
            try:
                os.kill(pid, signal.SIGTERM)
            except (OSError, ProcessLookupError):
                pass
        for _ in range(20):
            if not _pid_alive(pid):
                break
            time.sleep(0.25)

    SERVER_JSON.unlink(missing_ok=True)
    return {"status": "stopped", "pid": pid}


@mcp.tool()
def jupyter_status() -> dict[str, Any]:
    """Return the current JupyterLab runtime info and liveness."""
    info = _read_server_json()
    if not info:
        return {"running": False}
    alive = _pid_alive(info.get("pid", -1))
    return {"running": alive, **info, "url_with_token": _tokenized_url(info) if alive else None}


@mcp.tool()
def open_in_browser() -> dict[str, Any]:
    """Re-open the running JupyterLab URL in the browser."""
    info = _read_server_json()
    if not info or not _pid_alive(info.get("pid", -1)):
        raise RuntimeError("JupyterLab is not running. Call start_jupyter first.")
    url = _tokenized_url(info)
    subprocess.Popen([XDG_OPEN, url], start_new_session=True)
    return {"opened": url}


def main() -> None:
    mcp.run()


if __name__ == "__main__":
    main()
