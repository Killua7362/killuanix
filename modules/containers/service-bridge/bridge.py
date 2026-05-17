"""service-bridge — tri-state status + systemd control for quadlet containers.

Endpoints:
    GET  /services?homepage_only=true|false
        Returns [{name, unit, url, icon, status}] where status is one of
        "up", "down", or "error".
            down  : systemd unit is not active
            error : unit is active AND url is set AND probe failed/non-2xx/3xx
            up    : unit is active AND (url is null OR probe ok)
    POST /services/{unit}/{action}
        action ∈ {start, stop, restart}. Unit must be in the on-disk allowlist
        loaded from /etc/service-bridge/services.json at startup.

Runs as root on 127.0.0.1:8770. Behind no auth — protected by the loopback
bind. CORS is allow-listed to the glance origin so its `custom-api` widget
can call POST endpoints from the browser.
"""

import asyncio
import json
import os
from typing import Optional

import httpx
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse

CONFIG_PATH = os.environ.get("SERVICE_BRIDGE_CONFIG", "/etc/service-bridge/services.json")
GLANCE_ORIGIN = os.environ.get("SERVICE_BRIDGE_CORS_ORIGIN", "http://localhost:8880")
PROBE_TIMEOUT = float(os.environ.get("SERVICE_BRIDGE_PROBE_TIMEOUT", "3"))
ACTIONS = frozenset({"start", "stop", "restart"})

# FreshRSS Greader API config — credentials come from systemd EnvironmentFile
# populated by service-bridge-env.service (sops-backed). The bridge talks to
# FreshRSS over the Greader-compatible endpoint at /api/greader.php, lists
# user categories via /tag/list, and fetches Atom-formatted articles per
# category via /reader/atom/user/-/label/<name>.
FRESHRSS_BASE = os.environ.get("FRESHRSS_BASE", "http://localhost:8083").rstrip("/")
FRESHRSS_USER = os.environ.get("FRESHRSS_USER", "akshay")
FRESHRSS_API_PW = os.environ.get("FRESHRSS_API_PASSWORD", "")
FEEDS_LIMIT = 40

with open(CONFIG_PATH) as f:
    _cfg = json.load(f)

# Normalize: config is the nix attrset serialised to JSON. Keep order.
def _resolve_icon(icon: Optional[str]) -> str:
    if not icon:
        return ""
    if icon.startswith("si:"):
        return "https://cdn.simpleicons.org/" + icon[3:]
    if icon.startswith("di:"):
        return "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/" + icon[3:] + ".svg"
    return icon


SERVICES: list[dict] = _cfg["services"]
for _s in SERVICES:
    _s["iconUrl"] = _resolve_icon(_s.get("icon"))
ALLOWED_UNITS = {s["unit"] for s in SERVICES}

app = FastAPI(title="service-bridge")
app.add_middleware(
    CORSMiddleware,
    allow_origins=[GLANCE_ORIGIN],
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)


async def systemctl_is_active(unit: str) -> bool:
    proc = await asyncio.create_subprocess_exec(
        "systemctl", "is-active", "--quiet", unit,
        stdout=asyncio.subprocess.DEVNULL,
        stderr=asyncio.subprocess.DEVNULL,
    )
    rc = await proc.wait()
    return rc == 0


async def http_probe(url: str, allow_insecure: bool) -> bool:
    try:
        async with httpx.AsyncClient(
            timeout=PROBE_TIMEOUT, verify=not allow_insecure, follow_redirects=False
        ) as client:
            r = await client.get(url)
            return 200 <= r.status_code < 400
    except Exception:
        return False


async def status_for(svc: dict) -> str:
    active = await systemctl_is_active(svc["unit"])
    if not active:
        return "down"
    url = svc.get("url")
    if not url:
        return "up"
    ok = await http_probe(url, svc.get("allowInsecure", False))
    return "up" if ok else "error"


@app.get("/services")
async def list_services(homepage_only: bool = False):
    pool = [s for s in SERVICES if (s.get("homepage", False) if homepage_only else True)]
    statuses = await asyncio.gather(*(status_for(s) for s in pool))
    return [
        {
            "name": s["name"],
            "unit": s["unit"],
            "url": s.get("url") or "",
            "iconUrl": s["iconUrl"],
            "status": status,
        }
        for s, status in zip(pool, statuses)
    ]


@app.post("/services/{unit}/{action}")
async def control(unit: str, action: str):
    if unit not in ALLOWED_UNITS:
        raise HTTPException(status_code=404, detail="unit not in allowlist")
    if action not in ACTIONS:
        raise HTTPException(status_code=400, detail="action must be start|stop|restart")
    proc = await asyncio.create_subprocess_exec(
        "systemctl", action, unit,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    _, stderr = await proc.communicate()
    if proc.returncode != 0:
        return {"ok": False, "rc": proc.returncode, "stderr": stderr.decode(errors="replace")}
    return {"ok": True}


@app.get("/healthz")
async def healthz():
    return {"ok": True, "services": len(SERVICES)}


_UI_HTML = """<!doctype html>
<html><head><meta charset="utf-8"><title>Containers</title>
<style>
  :root { color-scheme: dark; }
  html, body { margin: 0; padding: 0; background: hsl(220, 10%, 6%); color: hsl(220, 10%, 90%); font-family: ui-sans-serif, system-ui, -apple-system, sans-serif; font-size: 16px; overflow: hidden; }
  body { padding: 1rem; }
  .sb-list { display: flex; flex-direction: column; gap: 0.7rem; }
  .sb-row { display: grid; grid-template-columns: 3rem 1fr auto auto; align-items: center; gap: 1.1rem; padding: 1rem 1.2rem; background: hsl(220, 10%, 10%); border: 1px solid hsl(220, 10%, 15%); border-radius: 10px; }
  .sb-row img { width: 2.6rem; height: 2.6rem; object-fit: contain; }
  .sb-meta { display: flex; flex-direction: column; min-width: 0; gap: 0.15rem; }
  .sb-name { font-size: 1.25rem; font-weight: 500; }
  .sb-unit { font-size: 0.95rem; color: hsl(220, 10%, 60%); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .sb-pill { display: inline-block; padding: 0.2rem 0.85rem; border-radius: 999px; font-size: 0.85rem; letter-spacing: 0.05em; text-transform: uppercase; font-weight: 500; }
  .sb-pill.up    { background: hsla(140, 60%, 55%, 0.18); color: hsl(140, 60%, 65%); }
  .sb-pill.down  { background: hsla(220, 10%, 50%, 0.18); color: hsl(220, 10%, 70%); }
  .sb-pill.error { background: hsla(0, 70%, 60%, 0.22); color: hsl(0, 70%, 70%); }
  .sb-btns { display: flex; gap: 0.45rem; }
  .sb-btn { font-size: 0.95rem; padding: 0.45rem 0.95rem; border-radius: 6px; border: 1px solid hsl(220, 10%, 25%); background: hsl(220, 10%, 14%); color: hsl(220, 10%, 85%); cursor: pointer; font-family: inherit; }
  .sb-btn:hover { border-color: hsl(170, 75%, 55%); color: hsl(170, 75%, 65%); }
  .sb-btn.stop:hover, .sb-btn.restart:hover { border-color: hsl(0, 70%, 60%); color: hsl(0, 70%, 70%); }
  .sb-busy { opacity: 0.5; pointer-events: none; }
</style></head>
<body>
<div class="sb-list" id="list">Loading…</div>
<script>
const API = "http://localhost:8770";
async function load() {
  const r = await fetch(API + "/services");
  const data = await r.json();
  const list = document.getElementById("list");
  list.innerHTML = "";
  for (const s of data) {
    const row = document.createElement("div");
    row.className = "sb-row";
    row.innerHTML = `
      <img src="${s.iconUrl}" alt="">
      <div class="sb-meta">
        <span class="sb-name">${s.name}</span>
        <span class="sb-unit">${s.unit}</span>
      </div>
      <span class="sb-pill ${s.status}">${s.status}</span>
      <div class="sb-btns">
        <button class="sb-btn start" data-action="start">Start</button>
        <button class="sb-btn stop" data-action="stop">Stop</button>
        <button class="sb-btn restart" data-action="restart">Restart</button>
      </div>`;
    row.querySelectorAll("button").forEach(b => {
      b.addEventListener("click", () => act(s.unit, b.dataset.action, row));
    });
    list.appendChild(row);
  }
}
async function act(unit, action, row) {
  if (action !== "start" && !confirm(`${action[0].toUpperCase()+action.slice(1)} ${unit}?`)) return;
  row.classList.add("sb-busy");
  try {
    const r = await fetch(`${API}/services/${encodeURIComponent(unit)}/${action}`, { method: "POST" });
    const j = await r.json();
    if (!j.ok) alert(`Failed: ${j.stderr || ("rc=" + j.rc)}`);
  } catch (e) {
    alert("Bridge error: " + e);
  }
  setTimeout(load, 600);
}
load();
setInterval(load, 30000);
</script>
</body></html>"""


@app.get("/ui", response_class=HTMLResponse)
async def ui():
    return _UI_HTML


# ── RSS feeds widget ────────────────────────────────────────────────────
import xml.etree.ElementTree as ET
from email.utils import parsedate_to_datetime
from datetime import datetime, timezone


def _parse_feed(xml_bytes: bytes, feed_title: str) -> list[dict]:
    items: list[dict] = []
    try:
        root = ET.fromstring(xml_bytes)
    except ET.ParseError:
        return items
    # RSS 2.0
    for it in root.iter("item"):
        title = (it.findtext("title") or "").strip()
        link = (it.findtext("link") or "").strip()
        pub = it.findtext("pubDate") or it.findtext("{http://purl.org/dc/elements/1.1/}date") or ""
        items.append({"title": title, "url": link, "feed": feed_title, "published": pub})
    # Atom
    ns = "{http://www.w3.org/2005/Atom}"
    for it in root.iter(ns + "entry"):
        title = (it.findtext(ns + "title") or "").strip()
        link_el = it.find(ns + "link")
        link = link_el.get("href") if link_el is not None else ""
        pub = it.findtext(ns + "published") or it.findtext(ns + "updated") or ""
        items.append({"title": title, "url": link, "feed": feed_title, "published": pub})
    return items


def _parse_date(s: str):
    if not s:
        return datetime.min.replace(tzinfo=timezone.utc)
    try:
        return parsedate_to_datetime(s)
    except (TypeError, ValueError):
        pass
    try:
        return datetime.fromisoformat(s.replace("Z", "+00:00"))
    except ValueError:
        return datetime.min.replace(tzinfo=timezone.utc)


# ── FreshRSS Greader API client ────────────────────────────────────────
import time

_auth_token: Optional[str] = None
_categories_cache: list[str] = []
_categories_expiry: float = 0.0


async def _greader_login(client: httpx.AsyncClient) -> str:
    global _auth_token
    if _auth_token:
        return _auth_token
    if not FRESHRSS_API_PW:
        raise RuntimeError("FRESHRSS_API_PASSWORD not set")
    r = await client.post(
        f"{FRESHRSS_BASE}/api/greader.php/accounts/ClientLogin",
        data={"Email": FRESHRSS_USER, "Passwd": FRESHRSS_API_PW},
    )
    if r.status_code != 200:
        raise RuntimeError(f"freshrss ClientLogin failed: {r.status_code} {r.text[:200]}")
    for line in r.text.splitlines():
        if line.startswith("Auth="):
            _auth_token = line[5:]
            return _auth_token
    raise RuntimeError("no Auth in ClientLogin response")


def _invalidate_auth():
    global _auth_token
    _auth_token = None


async def _greader_get(client: httpx.AsyncClient, path: str, params: Optional[dict] = None) -> httpx.Response:
    for attempt in range(2):
        auth = await _greader_login(client)
        r = await client.get(
            f"{FRESHRSS_BASE}/api/greader.php{path}",
            headers={"Authorization": f"GoogleLogin auth={auth}"},
            params=params or {},
        )
        if r.status_code == 401 and attempt == 0:
            _invalidate_auth()
            continue
        return r
    return r


async def _greader_categories(client: httpx.AsyncClient) -> list[str]:
    global _categories_cache, _categories_expiry
    now = time.time()
    if _categories_cache and now < _categories_expiry:
        return _categories_cache
    r = await _greader_get(client, "/reader/api/0/tag/list", {"output": "json"})
    if r.status_code != 200:
        return _categories_cache
    data = r.json()
    cats: list[str] = []
    for t in data.get("tags", []):
        tid = t.get("id", "")
        # Category IDs look like "user/-/label/Tech". Filter out state/* tags.
        marker = "/label/"
        if marker in tid:
            cats.append(tid.split(marker, 1)[1])
    _categories_cache = sorted(set(cats))
    _categories_expiry = now + 3600
    return _categories_cache


async def _greader_fetch(client: httpx.AsyncClient, category: Optional[str]) -> list[dict]:
    # FreshRSS's atom variant of GReader returns "Bad Request!" on some builds,
    # so we use the JSON stream/contents endpoint instead.
    from urllib.parse import quote
    if category:
        stream_id = f"user/-/label/{quote(category, safe='')}"
        feed_label = category
    else:
        stream_id = "user/-/state/com.google/reading-list"
        feed_label = "All"
    path = f"/reader/api/0/stream/contents/{stream_id}"
    r = await _greader_get(client, path, {"n": str(FEEDS_LIMIT), "output": "json"})
    if r.status_code != 200:
        return []
    try:
        data = r.json()
    except ValueError:
        return []
    # Spec form: {"items": [...]}. Some FreshRSS builds return the bare array.
    raw = data.get("items") if isinstance(data, dict) else data
    if not isinstance(raw, list):
        return []
    items: list[dict] = []
    for it in raw:
        title = (it.get("title") or "").strip()
        url = ""
        for alt in it.get("alternate") or []:
            href = alt.get("href")
            if href:
                url = href
                break
        if not url:
            url = it.get("canonical", [{}])[0].get("href", "") if isinstance(it.get("canonical"), list) else ""
        # GReader publishes epoch seconds in `published`; fall back to crawlTimeMsec.
        pub_raw = it.get("published")
        if pub_raw is None and "crawlTimeMsec" in it:
            try:
                pub_raw = int(it["crawlTimeMsec"]) // 1000
            except (TypeError, ValueError):
                pub_raw = None
        if isinstance(pub_raw, (int, float)):
            pub = datetime.fromtimestamp(pub_raw, tz=timezone.utc).isoformat()
        else:
            pub = str(pub_raw or "")
        origin = it.get("origin") or {}
        feed_name = (origin.get("title") or feed_label).strip()
        items.append({"title": title, "url": url, "feed": feed_name, "published": pub})
    return items


@app.get("/feeds/categories")
async def feeds_categories():
    try:
        async with httpx.AsyncClient(timeout=10, follow_redirects=True) as client:
            return await _greader_categories(client)
    except Exception as e:
        return {"error": str(e)}


@app.get("/feeds/data")
async def feeds_data(category: Optional[str] = None):
    try:
        async with httpx.AsyncClient(timeout=15, follow_redirects=True) as client:
            items = await _greader_fetch(client, category)
    except Exception as e:
        return {"error": str(e)}
    items.sort(key=lambda x: _parse_date(x["published"]), reverse=True)
    return items[:FEEDS_LIMIT]


_FEEDS_HTML = """<!doctype html>
<html><head><meta charset="utf-8"><title>Feeds</title>
<style>
  :root { color-scheme: dark; }
  html, body { margin: 0; padding: 0; background: hsl(220, 10%, 6%); color: hsl(220, 10%, 90%); font-family: ui-sans-serif, system-ui, -apple-system, sans-serif; font-size: 14px; height: 100%; }
  body { display: flex; flex-direction: column; }
  header { display: flex; justify-content: space-between; align-items: center; padding: 0.55rem 0.85rem; border-bottom: 1px solid hsl(220, 10%, 14%); background: hsl(220, 10%, 8%); gap: 0.5rem; }
  .tabs { display: flex; gap: 0.25rem; overflow-x: auto; }
  .tab { background: transparent; border: 1px solid hsl(220, 10%, 18%); color: hsl(220, 10%, 65%); border-radius: 999px; padding: 0.25rem 0.7rem; cursor: pointer; font-family: inherit; font-size: 0.78rem; white-space: nowrap; }
  .tab:hover { color: hsl(220, 10%, 90%); border-color: hsl(220, 10%, 30%); }
  .tab.active { background: hsla(170, 75%, 55%, 0.15); border-color: hsl(170, 75%, 45%); color: hsl(170, 75%, 70%); }
  .refresh { background: hsl(220, 10%, 14%); border: 1px solid hsl(220, 10%, 25%); color: hsl(220, 10%, 85%); border-radius: 4px; padding: 0.3rem 0.7rem; cursor: pointer; font-family: inherit; font-size: 0.85rem; display: inline-flex; align-items: center; gap: 0.35rem; flex-shrink: 0; }
  .refresh:hover { border-color: hsl(170, 75%, 55%); color: hsl(170, 75%, 65%); }
  .refresh.spin svg { animation: spin 1s linear infinite; }
  @keyframes spin { to { transform: rotate(360deg); } }
  ul.list { list-style: none; margin: 0; padding: 0.45rem 0.6rem; overflow-y: auto; flex: 1; }
  li.item { padding: 0.5rem 0.55rem; border-radius: 6px; }
  li.item:hover { background: hsl(220, 10%, 10%); }
  li.item + li.item { border-top: 1px solid hsl(220, 10%, 12%); }
  li.item a { color: hsl(220, 10%, 90%); text-decoration: none; font-size: 0.95rem; line-height: 1.3; }
  li.item a:hover { color: hsl(170, 75%, 65%); }
  li.item .meta { font-size: 0.75rem; color: hsl(220, 10%, 55%); margin-top: 0.2rem; display: flex; gap: 0.6rem; }
  .empty { padding: 1rem; text-align: center; color: hsl(220, 10%, 55%); }
</style></head>
<body>
<header>
  <div class="tabs" id="tabs"></div>
  <button class="refresh" id="refresh" title="Refresh feeds">
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="23 4 23 10 17 10"/><polyline points="1 20 1 14 7 14"/><path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"/></svg>
    Refresh
  </button>
</header>
<ul class="list" id="list"><li class="empty">Loading…</li></ul>
<script>
let TABS = ["All"];
let activeTab = "All";
const btn = document.getElementById("refresh");
const list = document.getElementById("list");
const tabsEl = document.getElementById("tabs");

function renderTabs() {
  tabsEl.innerHTML = "";
  for (const t of TABS) {
    const b = document.createElement("button");
    b.className = "tab" + (t === activeTab ? " active" : "");
    b.textContent = t;
    b.addEventListener("click", () => { activeTab = t; renderTabs(); load(); });
    tabsEl.appendChild(b);
  }
}
function fmtDate(s) {
  if (!s) return "";
  const d = new Date(s);
  if (isNaN(d)) return "";
  const now = new Date();
  const diff = (now - d) / 1000;
  if (diff < 60) return "just now";
  if (diff < 3600) return Math.floor(diff/60) + "m ago";
  if (diff < 86400) return Math.floor(diff/3600) + "h ago";
  if (diff < 86400*30) return Math.floor(diff/86400) + "d ago";
  return d.toLocaleDateString();
}
function render(items) {
  if (!items.length) {
    list.innerHTML = '<li class="empty">No items.</li>';
    return;
  }
  list.innerHTML = "";
  for (const it of items) {
    const li = document.createElement("li");
    li.className = "item";
    const a = document.createElement("a");
    a.href = it.url;
    a.target = "_blank";
    a.rel = "noreferrer";
    a.textContent = it.title;
    li.appendChild(a);
    const meta = document.createElement("div");
    meta.className = "meta";
    const feed = document.createElement("span");
    feed.textContent = it.feed;
    meta.appendChild(feed);
    const time = document.createElement("span");
    time.textContent = fmtDate(it.published);
    meta.appendChild(time);
    li.appendChild(meta);
    list.appendChild(li);
  }
}
async function loadCategories() {
  try {
    const r = await fetch("/feeds/categories?ts=" + Date.now(), { cache: "no-store" });
    const data = await r.json();
    if (Array.isArray(data)) {
      TABS = ["All"].concat(data);
    }
  } catch (e) { /* tabs stay at default */ }
  renderTabs();
}
async function load() {
  btn.classList.add("spin");
  try {
    const params = new URLSearchParams({ ts: Date.now() });
    if (activeTab !== "All") params.set("category", activeTab);
    const r = await fetch("/feeds/data?" + params, { cache: "no-store" });
    const data = await r.json();
    if (!Array.isArray(data)) {
      list.innerHTML = '<li class="empty">Error: ' + (data.error || "unknown") + '</li>';
      return;
    }
    render(data);
  } catch (e) {
    list.innerHTML = '<li class="empty">Error: ' + e + '</li>';
  } finally {
    btn.classList.remove("spin");
  }
}
btn.addEventListener("click", () => { loadCategories(); load(); });
(async () => { await loadCategories(); load(); })();
</script>
</body></html>"""


@app.get("/feeds", response_class=HTMLResponse)
async def feeds_ui():
    return _FEEDS_HTML
