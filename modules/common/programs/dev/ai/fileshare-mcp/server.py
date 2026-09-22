# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "mcp>=1.0,<2",
#   "httpx>=0.27",
# ]
# ///
"""fileshare MCP server — upload files to litterbox (catbox), get a share link.

Backend is litterbox.catbox.moe — anonymous temporary file host, no auth.
Expiry is one of a FIXED set of buckets: 1h / 12h / 24h / 72h (litterbox has
no arbitrary TTL). Default is 1h. Files auto-delete at expiry;
litterbox has NO per-file delete or listing API, so there is no delete tool —
`list_uploads` reflects only a local ledger of what this MCP uploaded.

litterbox is immutable: no in-place edit. "Modifying" a file means
re-uploading (upload_file / upload_content), which yields a NEW url.

(Previous backend 0x0.st disabled uploads in 2026 over AI-bot spam; before
that transfer.sh's public host was too flaky. litterbox = catbox infra,
reliable.)

Env:
  FILESHARE_API_URL       (default: https://litterbox.catbox.moe/resources/internals/api.php)
  FILESHARE_DEFAULT_EXPIRY(default: 1h — one of 1h/12h/24h/72h)
  FILESHARE_LEDGER        (default: $XDG_DATA_HOME/fileshare-mcp/uploads.json)
  FILESHARE_USER_AGENT    (default: fileshare-mcp/1.0)
"""
from __future__ import annotations

import json
import os
import time
from pathlib import Path
from typing import Any

import httpx
from mcp.server.fastmcp import FastMCP

API = os.environ.get(
    "FILESHARE_API_URL",
    "https://litterbox.catbox.moe/resources/internals/api.php",
)
VALID_EXPIRY = ("1h", "12h", "24h", "72h")
DEFAULT_EXPIRY = os.environ.get("FILESHARE_DEFAULT_EXPIRY", "1h")
UA = os.environ.get("FILESHARE_USER_AGENT", "fileshare-mcp/1.0")

_data_home = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
LEDGER = Path(os.environ.get("FILESHARE_LEDGER", f"{_data_home}/fileshare-mcp/uploads.json"))

_client = httpx.Client(timeout=120.0, headers={"User-Agent": UA}, follow_redirects=True)


def _load_ledger() -> list[dict[str, Any]]:
    try:
        return json.loads(LEDGER.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return []


def _save_ledger(entries: list[dict[str, Any]]) -> None:
    LEDGER.parent.mkdir(parents=True, exist_ok=True)
    tmp = LEDGER.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(entries, indent=2), encoding="utf-8")
    tmp.replace(LEDGER)


def _record(entry: dict[str, Any]) -> None:
    entries = [e for e in _load_ledger() if e.get("url") != entry["url"]]
    entries.append(entry)
    _save_ledger(entries)


def _norm_expiry(expiry: str) -> str:
    e = str(expiry).strip().lower()
    if e not in VALID_EXPIRY:
        raise ValueError(f"expiry must be one of {VALID_EXPIRY}, got {expiry!r}")
    return e


def _do_upload(filename: str, blob: bytes, expiry: str) -> dict[str, Any]:
    exp = _norm_expiry(expiry)
    r = _client.post(
        API,
        data={"reqtype": "fileupload", "time": exp},
        files={"fileToUpload": (filename, blob)},
    )
    body = r.text.strip()
    if r.status_code >= 400 or not body.lower().startswith("http"):
        raise RuntimeError(f"litterbox upload failed ({r.status_code}): {body}")
    entry = {
        "url": body,
        "filename": filename,
        "size": len(blob),
        "expiry": exp,
        "uploaded_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    }
    _record(entry)
    return entry


mcp = FastMCP("fileshare")


@mcp.tool()
def upload_file(path: str, expiry: str = DEFAULT_EXPIRY) -> dict:
    """Upload an existing local file to litterbox and return a shareable download link.

    expiry is one of '1h','12h','24h','72h' (default '1h') — litterbox
    has no arbitrary TTL. Files auto-delete at expiry (no manual delete).
    Multiple people can download the same link. Max 1 GiB. Returns
    url/filename/size/expiry.
    """
    p = Path(os.path.expanduser(path))
    if not p.is_file():
        raise FileNotFoundError(f"not a file: {p}")
    return _do_upload(p.name, p.read_bytes(), expiry)


@mcp.tool()
def upload_content(filename: str, content: str, expiry: str = DEFAULT_EXPIRY) -> dict:
    """Create a file from inline text `content` and upload it to litterbox.

    Use to share generated output without writing a file to disk first.
    `filename` sets the download name (e.g. notes.md). expiry: 1h/12h/24h/72h,
    default 1h.
    """
    return _do_upload(filename, content.encode("utf-8"), expiry)


@mcp.tool()
def list_uploads() -> list[dict]:
    """List files uploaded from this host (local ledger): url/filename/size/expiry/uploaded_at.

    litterbox has no listing API, so this reflects only uploads made through
    this MCP; entries past their expiry are stale (the link is already dead).
    """
    return [
        {k: e.get(k) for k in ("url", "filename", "size", "expiry", "uploaded_at")}
        for e in _load_ledger()
    ]


if __name__ == "__main__":
    mcp.run()
