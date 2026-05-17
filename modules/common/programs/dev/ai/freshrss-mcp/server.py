# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "mcp>=1.0",
#   "httpx>=0.27",
# ]
# ///
"""FreshRSS MCP server — Greader API client exposed as MCP tools.

Reads credentials from env:
  FRESHRSS_BASE_URL          (default: http://localhost:8083)
  FRESHRSS_USER              (default: killua)
  FRESHRSS_API_PASSWORD      OR
  FRESHRSS_API_PASSWORD_FILE (path to sops-decrypted secret)
"""
from __future__ import annotations

import os
import sys
from typing import Any

import httpx
from mcp.server.fastmcp import FastMCP

BASE = os.environ.get("FRESHRSS_BASE_URL", "http://localhost:8083")
USER = os.environ.get("FRESHRSS_USER", "killua")
PW = os.environ.get("FRESHRSS_API_PASSWORD")
PW_FILE = os.environ.get("FRESHRSS_API_PASSWORD_FILE")
if not PW and PW_FILE:
    try:
        with open(PW_FILE, encoding="utf-8") as f:
            PW = f.read().strip()
    except OSError as exc:
        sys.stderr.write(f"freshrss-mcp: cannot read {PW_FILE}: {exc}\n")
        sys.exit(1)
if not PW:
    sys.stderr.write("freshrss-mcp: FRESHRSS_API_PASSWORD[_FILE] not set\n")
    sys.exit(1)

GREADER = f"{BASE.rstrip('/')}/api/greader.php"
_auth: str | None = None
_write_token: str | None = None
_client = httpx.Client(timeout=30.0)


def _login() -> str:
    global _auth
    if _auth:
        return _auth
    r = _client.post(
        f"{GREADER}/accounts/ClientLogin",
        data={"Email": USER, "Passwd": PW},
    )
    r.raise_for_status()
    for line in r.text.splitlines():
        if line.startswith("Auth="):
            _auth = line[5:].strip()
            return _auth
    raise RuntimeError(f"ClientLogin returned no Auth token: {r.text!r}")


def _headers() -> dict[str, str]:
    return {"Authorization": f"GoogleLogin auth={_login()}"}


def _api_get(path: str, params: dict | None = None) -> dict:
    p = {"output": "json", **(params or {})}
    r = _client.get(f"{GREADER}/reader/api/0/{path}", headers=_headers(), params=p)
    r.raise_for_status()
    return r.json()


def _token() -> str:
    global _write_token
    if _write_token:
        return _write_token
    r = _client.get(f"{GREADER}/reader/api/0/token", headers=_headers())
    r.raise_for_status()
    _write_token = r.text.strip()
    return _write_token


def _items(
    stream: str,
    n: int = 20,
    exclude: str | None = None,
    query: str | None = None,
) -> list[dict]:
    params: dict[str, Any] = {"n": max(1, min(n, 200))}
    if exclude:
        params["xt"] = exclude
    if query:
        params["q"] = query
    data = _api_get(f"stream/contents/{stream}", params)
    out = []
    for it in data.get("items", []):
        summary = (it.get("summary") or {}).get("content", "") or ""
        out.append(
            {
                "id": it.get("id"),
                "title": it.get("title"),
                "url": (it.get("alternate") or [{}])[0].get("href"),
                "feed": (it.get("origin") or {}).get("title"),
                "published": it.get("published"),
                "summary": summary[:3000],
            }
        )
    return out


mcp = FastMCP("freshrss")


@mcp.tool()
def list_unread(limit: int = 20) -> list[dict]:
    """Most recent unread items across all feeds. Returns id/title/url/feed/published/summary."""
    return _items(
        "user/-/state/com.google/reading-list",
        n=limit,
        exclude="user/-/state/com.google/read",
    )


@mcp.tool()
def list_starred(limit: int = 20) -> list[dict]:
    """Starred (favourited) items, most recent first."""
    return _items("user/-/state/com.google/starred", n=limit)


@mcp.tool()
def search(query: str, limit: int = 20, unread_only: bool = False) -> list[dict]:
    """Full-text search items. Set unread_only=True to restrict to unread."""
    return _items(
        "user/-/state/com.google/reading-list",
        n=limit,
        query=query,
        exclude="user/-/state/com.google/read" if unread_only else None,
    )


@mcp.tool()
def list_feeds() -> list[dict]:
    """List subscribed feeds (id, title, url, categories). Feed ids feed into items_from_feed()."""
    data = _api_get("subscription/list")
    return [
        {
            "id": s.get("id"),
            "title": s.get("title"),
            "url": s.get("url"),
            "categories": [c.get("label") for c in s.get("categories", [])],
        }
        for s in data.get("subscriptions", [])
    ]


@mcp.tool()
def items_from_feed(feed_id: str, limit: int = 20, unread_only: bool = True) -> list[dict]:
    """Items from one feed. feed_id is the value returned by list_feeds()."""
    return _items(
        feed_id,
        n=limit,
        exclude="user/-/state/com.google/read" if unread_only else None,
    )


@mcp.tool()
def list_categories() -> list[dict]:
    """List feed categories (Greader labels)."""
    data = _api_get("tag/list")
    return [{"id": t.get("id"), "label": (t.get("id") or "").split("/label/")[-1]} for t in data.get("tags", [])]


@mcp.tool()
def mark_read(item_id: str) -> str:
    """Mark a single item as read. item_id from list_unread()."""
    r = _client.post(
        f"{GREADER}/reader/api/0/edit-tag",
        headers=_headers(),
        data={
            "i": item_id,
            "a": "user/-/state/com.google/read",
            "T": _token(),
        },
    )
    r.raise_for_status()
    return "ok"


@mcp.tool()
def star(item_id: str) -> str:
    """Star (favourite) a single item."""
    r = _client.post(
        f"{GREADER}/reader/api/0/edit-tag",
        headers=_headers(),
        data={
            "i": item_id,
            "a": "user/-/state/com.google/starred",
            "T": _token(),
        },
    )
    r.raise_for_status()
    return "ok"


if __name__ == "__main__":
    mcp.run()
