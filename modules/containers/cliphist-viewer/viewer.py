#!/usr/bin/env python3
"""Browser viewer for the cliphist clipboard store.

Serves an HTML grid of every cliphist entry (text + decoded image thumbnails) on
127.0.0.1:$CLIPHIST_VIEWER_PORT, with a filter bar (content search, type, date
range) and a CSV export. Each card has a copy button (→ wl-copy, mime-detected)
and opens a scrollable modal preview of the full decoded content on click.
Read-only otherwise. Stdlib only.

cliphist itself records no timestamps, so dates come from a sidecar written by
the cliphist watchers (see hyprland/clipboard.nix): $CLIPHIST_TIMESTAMPS, lines
of "<id>\\t<iso8601>". Entries without a recorded stamp show "—".
"""
import csv
import html
import io
import os
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HOST = os.environ.get("CLIPHIST_VIEWER_HOST", "127.0.0.1")
PORT = int(os.environ.get("CLIPHIST_VIEWER_PORT", "8899"))
TS_PATH = os.environ.get(
    "CLIPHIST_TIMESTAMPS",
    os.path.join(os.environ.get("HOME", ""), ".cache/cliphist/timestamps"),
)

IMG_HINT = ("png", "jpg", "jpeg", "bmp", "gif", "webp")

# Inline icons (stroke = currentColor).
SVG_COPY = ('<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" '
            'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">'
            '<rect x="9" y="9" width="13" height="13" rx="2"/>'
            '<path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>')
SVG_MAX = ('<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" '
           'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">'
           '<path d="M15 3h6v6M9 21H3v-6M21 3l-7 7M3 21l7-7"/></svg>')
SVG_CLOSE = ('<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" '
             'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">'
             '<path d="M18 6 6 18M6 6l12 12"/></svg>')


def timestamps():
    """id -> iso8601 string, from the sidecar. Last write for an id wins."""
    out = {}
    try:
        with open(TS_PATH) as f:
            for line in f:
                if "\t" in line:
                    cid, ts = line.rstrip("\n").split("\t", 1)
                    out[cid.strip()] = ts.strip()
    except FileNotFoundError:
        pass
    return out


def cliphist_list():
    """List of dicts {id, preview, is_img}, newest first."""
    out = subprocess.run(["cliphist", "list"], capture_output=True, text=True).stdout
    rows = []
    for line in out.splitlines():
        if "\t" not in line:
            continue
        cid, preview = line.split("\t", 1)
        low = preview.lower()
        is_img = "binary data" in low and any(t in low for t in IMG_HINT)
        rows.append({"id": cid.strip(), "preview": preview, "is_img": is_img})
    return rows


def decode(cid):
    """Raw bytes for a cliphist id. cliphist parses the id up to the first tab,
    so the id must be tab-terminated (a bare id fails Atoi)."""
    return subprocess.run(
        ["cliphist", "decode"], input=(cid + "\t").encode(), capture_output=True
    ).stdout


def mime_of(data):
    r = subprocess.run(["file", "--mime-type", "-b", "-"], input=data, capture_output=True)
    return r.stdout.decode(errors="replace").strip() or "application/octet-stream"


def human_ts(ts):
    """Date + HH:MM from an iso8601 stamp; em dash when unknown."""
    if not ts:
        return "—"
    return ts.replace("T", " ")[:16]


# ── Frontend ───────────────────────────────────────────────────────────────
# Utilitarian tool UI: information-design first. Token-based palette (both
# themes, biased-slate neutrals + single indigo accent), system-ui for chrome +
# JetBrainsMono for clipboard content/ids/timestamps. Cards open a scrollable
# modal preview; copy lives on a per-card button. %%CARDS%% is the only
# substitution so the CSS braces need no escaping.
PAGE = ("""<!doctype html>
<html lang="en" data-theme="">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Clipboard History</title>
<style>
  :root {
    --bg: #f6f7f9; --surface: #ffffff; --surface-2: #eef0f4;
    --border: #dfe3ea; --text: #1b1e26; --muted: #6b7280;
    --accent: #4f6bed; --accent-fg: #ffffff; --accent-weak: rgba(79,107,237,.10);
    --chip-txt-bg: rgba(79,107,237,.12); --chip-txt-fg: #3a52c9;
    --chip-img-bg: rgba(15,118,110,.14); --chip-img-fg: #0f766e;
    --shadow: 0 1px 2px rgba(16,20,32,.06), 0 6px 20px rgba(16,20,32,.06);
    --shadow-lg: 0 12px 48px rgba(16,20,32,.22);
    --scrim: rgba(16,20,32,.32);
    --font-ui: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
    --font-mono: "JetBrainsMono Nerd Font", "JetBrains Mono", ui-monospace, SFMono-Regular, Menlo, monospace;
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --bg: #0f1116; --surface: #161922; --surface-2: #1d2130;
      --border: #2a3040; --text: #e4e7ef; --muted: #8b93a6;
      --accent: #6d8bff; --accent-fg: #0f1116; --accent-weak: rgba(109,139,255,.14);
      --chip-txt-bg: rgba(109,139,255,.16); --chip-txt-fg: #a9bcff;
      --chip-img-bg: rgba(45,212,191,.16); --chip-img-fg: #6ee7d6;
      --shadow: 0 1px 2px rgba(0,0,0,.4), 0 8px 24px rgba(0,0,0,.35);
      --shadow-lg: 0 16px 56px rgba(0,0,0,.55);
      --scrim: rgba(0,0,0,.55);
    }
  }
  :root[data-theme="light"] {
    --bg: #f6f7f9; --surface: #ffffff; --surface-2: #eef0f4;
    --border: #dfe3ea; --text: #1b1e26; --muted: #6b7280;
    --accent: #4f6bed; --accent-fg: #ffffff; --accent-weak: rgba(79,107,237,.10);
    --chip-txt-bg: rgba(79,107,237,.12); --chip-txt-fg: #3a52c9;
    --chip-img-bg: rgba(15,118,110,.14); --chip-img-fg: #0f766e;
    --shadow: 0 1px 2px rgba(16,20,32,.06), 0 6px 20px rgba(16,20,32,.06);
    --shadow-lg: 0 12px 48px rgba(16,20,32,.22);
    --scrim: rgba(16,20,32,.32);
  }
  :root[data-theme="dark"] {
    --bg: #0f1116; --surface: #161922; --surface-2: #1d2130;
    --border: #2a3040; --text: #e4e7ef; --muted: #8b93a6;
    --accent: #6d8bff; --accent-fg: #0f1116; --accent-weak: rgba(109,139,255,.14);
    --chip-txt-bg: rgba(109,139,255,.16); --chip-txt-fg: #a9bcff;
    --chip-img-bg: rgba(45,212,191,.16); --chip-img-fg: #6ee7d6;
    --shadow: 0 1px 2px rgba(0,0,0,.4), 0 8px 24px rgba(0,0,0,.35);
    --shadow-lg: 0 16px 56px rgba(0,0,0,.55);
    --scrim: rgba(0,0,0,.55);
  }

  * { box-sizing: border-box; }
  html { scroll-behavior: smooth; }
  body {
    margin: 0; background: var(--bg); color: var(--text);
    font-family: var(--font-ui); font-size: 14px; line-height: 1.5;
    -webkit-font-smoothing: antialiased;
  }

  /* ── Sticky toolbar ── */
  .topbar {
    position: sticky; top: 0; z-index: 10;
    background: color-mix(in srgb, var(--bg) 82%, transparent);
    backdrop-filter: blur(10px); -webkit-backdrop-filter: blur(10px);
    border-bottom: 1px solid var(--border);
    padding: 14px 22px; display: flex; flex-direction: column; gap: 12px;
  }
  .brand { display: flex; align-items: center; gap: 10px; }
  .brand svg { width: 20px; height: 20px; color: var(--accent); flex: none; }
  .brand h1 { font-size: 15px; font-weight: 650; margin: 0; letter-spacing: -.01em; }
  .count {
    font-family: var(--font-mono); font-size: 12px; color: var(--muted);
    font-variant-numeric: tabular-nums; margin-left: auto;
  }

  .filters { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; }
  .field { display: flex; align-items: center; gap: 6px; }
  .field > label {
    font-size: 11px; text-transform: uppercase; letter-spacing: .07em; color: var(--muted);
  }
  input, select, .btn {
    font-family: var(--font-ui); font-size: 13px; color: var(--text);
    background: var(--surface); border: 1px solid var(--border);
    border-radius: 8px; padding: 7px 10px; transition: border-color .12s, background .12s;
  }
  input[type="search"] {
    flex: 1 1 240px; min-width: 180px; font-family: var(--font-mono);
  }
  input:focus-visible, select:focus-visible, .btn:focus-visible, .card:focus-visible, .ico:focus-visible {
    outline: 2px solid var(--accent); outline-offset: 2px; border-color: var(--accent);
  }
  input:focus, select:focus { outline: none; border-color: var(--accent); }
  .btn { cursor: pointer; user-select: none; }
  .btn:hover { background: var(--surface-2); border-color: var(--accent); }
  .btn-accent { background: var(--accent); color: var(--accent-fg); border-color: var(--accent); }
  .btn-accent:hover { background: var(--accent); filter: brightness(1.06); color: var(--accent-fg); }
  a.btn { text-decoration: none; display: inline-flex; align-items: center; gap: 6px; }
  .icon-btn { padding: 7px 9px; line-height: 0; }
  .icon-btn svg { width: 16px; height: 16px; }

  /* ── Icon buttons on cards / modal ── */
  .ico {
    background: transparent; border: none; color: var(--muted); cursor: pointer;
    padding: 4px; border-radius: 7px; line-height: 0; display: inline-flex;
    transition: color .12s, background .12s;
  }
  .ico svg { width: 15px; height: 15px; }
  .ico:hover { color: var(--accent); background: var(--accent-weak); }
  .ico.ok { color: var(--accent); }

  /* ── Grid ── */
  .grid {
    display: grid; grid-template-columns: repeat(auto-fill, minmax(230px, 1fr));
    gap: 12px; padding: 20px 22px 60px;
  }
  .card {
    background: var(--surface); border: 1px solid var(--border); border-radius: 12px;
    padding: 0; cursor: pointer; overflow: hidden; display: flex; flex-direction: column;
    min-height: 92px; transition: transform .12s ease, box-shadow .12s ease, border-color .12s;
  }
  .card:hover { transform: translateY(-2px); box-shadow: var(--shadow); border-color: color-mix(in srgb, var(--accent) 45%, var(--border)); }
  .card-head {
    display: flex; align-items: center; gap: 8px; padding: 7px 8px 7px 12px;
    border-bottom: 1px solid var(--border); background: var(--surface-2);
    font-family: var(--font-mono); font-size: 11px; color: var(--muted);
    font-variant-numeric: tabular-nums;
  }
  .cid { font-weight: 600; }
  .chip {
    font-family: var(--font-ui); font-size: 9.5px; font-weight: 700; letter-spacing: .09em;
    text-transform: uppercase; padding: 2px 6px; border-radius: 999px; line-height: 1.4;
  }
  .chip-text { background: var(--chip-txt-bg); color: var(--chip-txt-fg); }
  .chip-image { background: var(--chip-img-bg); color: var(--chip-img-fg); }
  .ts { margin-left: auto; white-space: nowrap; }
  .body { padding: 11px 12px; overflow: hidden; }
  .txt {
    font-family: var(--font-mono); font-size: 12.5px; white-space: pre-wrap;
    word-break: break-word; max-height: 170px; overflow: hidden;
    -webkit-mask-image: linear-gradient(180deg, #000 78%, transparent);
            mask-image: linear-gradient(180deg, #000 78%, transparent);
  }
  .body img { max-width: 100%; max-height: 190px; object-fit: contain; display: block; border-radius: 6px; }

  .empty {
    grid-column: 1 / -1; text-align: center; color: var(--muted);
    padding: 64px 20px; font-family: var(--font-mono); font-size: 13px;
  }

  /* ── Modal preview ── */
  .backdrop {
    position: fixed; inset: 0; z-index: 50; display: flex; align-items: center;
    justify-content: center; padding: 28px; background: var(--scrim);
    backdrop-filter: blur(6px); -webkit-backdrop-filter: blur(6px);
  }
  .backdrop[hidden] { display: none; }
  .modal {
    display: flex; flex-direction: column; width: min(760px, 92vw); max-height: 82vh;
    background: var(--surface); border: 1px solid var(--border); border-radius: 14px;
    box-shadow: var(--shadow-lg); overflow: hidden;
  }
  .modal-head {
    display: flex; align-items: center; gap: 10px; padding: 12px 12px 12px 16px;
    border-bottom: 1px solid var(--border); background: var(--surface-2);
    font-family: var(--font-mono); font-size: 12px; color: var(--muted);
    font-variant-numeric: tabular-nums;
  }
  .modal-head .ts { margin-left: auto; }
  .modal-head .ico svg { width: 17px; height: 17px; }
  .modal-body { flex: 1 1 auto; overflow: auto; padding: 16px; }
  .modal-body pre {
    margin: 0; font-family: var(--font-mono); font-size: 13px; line-height: 1.55;
    white-space: pre-wrap; word-break: break-word; color: var(--text);
  }
  .modal-body img { max-width: 100%; height: auto; display: block; margin: 0 auto; border-radius: 8px; }

  /* ── Toast ── */
  .toast {
    position: fixed; bottom: 22px; left: 50%; transform: translate(-50%, 8px);
    background: var(--accent); color: var(--accent-fg); font-weight: 600; font-size: 13px;
    padding: 9px 18px; border-radius: 10px; box-shadow: var(--shadow); z-index: 60;
    opacity: 0; pointer-events: none; transition: opacity .16s, transform .16s;
  }
  .toast.show { opacity: 1; transform: translate(-50%, 0); }

  @media (prefers-reduced-motion: reduce) {
    * { transition: none !important; scroll-behavior: auto; }
    .card:hover { transform: none; }
  }
</style>
</head>
<body>
<header class="topbar">
  <div class="brand">
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
      <rect x="8" y="2" width="8" height="4" rx="1"/>
      <path d="M8 4H6a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V6a2 2 0 0 0-2-2h-2"/>
      <path d="M9 12h6M9 16h4"/>
    </svg>
    <h1>Clipboard History</h1>
    <span class="count" id="count"></span>
  </div>
  <div class="filters">
    <input type="search" id="q" placeholder="Search text…" autocomplete="off" aria-label="Search clipboard text">
    <select id="type" aria-label="Filter by type">
      <option value="all">All types</option>
      <option value="text">Text only</option>
      <option value="image">Images only</option>
    </select>
    <div class="field"><label for="from">from</label><input type="date" id="from"></div>
    <div class="field"><label for="to">to</label><input type="date" id="to"></div>
    <button class="btn" id="clear" type="button">Clear</button>
    <a class="btn btn-accent" href="/export.csv" download="clipboard-history.csv">Export CSV</a>
    <button class="btn icon-btn" id="theme" type="button" title="Toggle theme" aria-label="Toggle theme">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9z"/></svg>
    </button>
  </div>
</header>

<main class="grid" id="grid">%%CARDS%%</main>

<div class="backdrop" id="backdrop" hidden>
  <div class="modal" role="dialog" aria-modal="true" aria-label="Clipboard entry">
    <div class="modal-head">
      <span class="cid" id="m-id"></span>
      <span class="chip" id="m-chip"></span>
      <time class="ts" id="m-ts"></time>
      <button class="ico" id="m-copy" type="button" title="Copy" aria-label="Copy">""" + SVG_COPY + """</button>
      <button class="ico" id="m-close" type="button" title="Close" aria-label="Close">""" + SVG_CLOSE + """</button>
    </div>
    <div class="modal-body" id="m-body"></div>
  </div>
</div>

<div class="toast" id="toast">Copied</div>

<script>
  // ── Theme: default to OS, remember explicit choice ──
  const root = document.documentElement;
  const saved = localStorage.getItem("cliphist-theme");
  if (saved) root.dataset.theme = saved;
  document.getElementById("theme").addEventListener("click", () => {
    const dark = matchMedia("(prefers-color-scheme: dark)").matches;
    const cur = root.dataset.theme || (dark ? "dark" : "light");
    const next = cur === "dark" ? "light" : "dark";
    root.dataset.theme = next; localStorage.setItem("cliphist-theme", next);
  });

  // ── Filtering (client-side over data-* attributes) ──
  const cards = [...document.querySelectorAll(".card")];
  const q = document.getElementById("q"), type = document.getElementById("type");
  const from = document.getElementById("from"), to = document.getElementById("to");
  const count = document.getElementById("count"), grid = document.getElementById("grid");
  let emptyEl = null;
  function apply() {
    const term = q.value.trim().toLowerCase(), t = type.value, f = from.value, tt = to.value;
    let shown = 0;
    for (const c of cards) {
      let ok = true;
      if (term && !c.dataset.content.includes(term)) ok = false;
      if (t !== "all" && c.dataset.type !== t) ok = false;
      if (f || tt) {
        const day = c.dataset.ts ? c.dataset.ts.slice(0, 10) : "";
        if (!day) ok = false;                       // no recorded date → excluded by a date filter
        else { if (f && day < f) ok = false; if (tt && day > tt) ok = false; }
      }
      c.style.display = ok ? "" : "none";
      if (ok) shown++;
    }
    count.textContent = shown + " / " + cards.length + " shown";
    if (!emptyEl) { emptyEl = document.createElement("div"); emptyEl.className = "empty"; emptyEl.textContent = "No matching entries."; grid.appendChild(emptyEl); }
    emptyEl.style.display = shown ? "none" : "";
  }
  q.addEventListener("input", apply);
  [type, from, to].forEach(e => e.addEventListener("change", apply));
  document.getElementById("clear").addEventListener("click", () => { q.value = ""; type.value = "all"; from.value = ""; to.value = ""; apply(); q.focus(); });

  // ── Toast + copy ──
  const toast = document.getElementById("toast");
  let toastTimer = null;
  function flash(msg) {
    toast.textContent = msg; toast.classList.add("show");
    clearTimeout(toastTimer); toastTimer = setTimeout(() => toast.classList.remove("show"), 850);
  }
  async function copyId(id, btn) {
    try { await fetch("/copy/" + id, { method: "POST" }); } catch (e) { return; }
    flash("Copied");
    if (btn) { btn.classList.add("ok"); setTimeout(() => btn.classList.remove("ok"), 700); }
  }
  window.copyId = copyId;

  // ── Modal preview ──
  const backdrop = document.getElementById("backdrop");
  const mId = document.getElementById("m-id"), mChip = document.getElementById("m-chip");
  const mTs = document.getElementById("m-ts"), mBody = document.getElementById("m-body");
  const mCopy = document.getElementById("m-copy"), mClose = document.getElementById("m-close");
  let curId = null, lastFocus = null;
  async function openModal(id, type) {
    curId = id; lastFocus = document.activeElement;
    const card = document.querySelector('.card[data-id="' + id + '"]');
    mId.textContent = "#" + id;
    mTs.textContent = card ? card.querySelector(".ts").textContent : "";
    mChip.className = "chip " + (type === "image" ? "chip-image" : "chip-text");
    mChip.textContent = type === "image" ? "img" : "txt";
    mBody.innerHTML = "";
    if (type === "image") {
      const img = document.createElement("img");
      img.src = "/img/" + id; img.alt = "clipboard image #" + id;
      mBody.appendChild(img);
    } else {
      const pre = document.createElement("pre");
      pre.textContent = "Loading…"; mBody.appendChild(pre);
      try { const r = await fetch("/text/" + id); pre.textContent = await r.text(); }
      catch (e) { pre.textContent = "(failed to load)"; }
    }
    backdrop.hidden = false; document.body.style.overflow = "hidden";
    mBody.scrollTop = 0; mClose.focus();
  }
  function closeModal() {
    backdrop.hidden = true; document.body.style.overflow = ""; curId = null;
    if (lastFocus && lastFocus.focus) lastFocus.focus();
  }
  window.openModal = openModal;
  mClose.addEventListener("click", closeModal);
  mCopy.addEventListener("click", () => { if (curId) copyId(curId, mCopy); });
  backdrop.addEventListener("click", e => { if (e.target === backdrop) closeModal(); });
  document.addEventListener("keydown", e => { if (e.key === "Escape" && !backdrop.hidden) closeModal(); });

  apply();
</script>
</body></html>""")


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _send(self, code, body, ctype="text/html; charset=utf-8", headers=None):
        if isinstance(body, str):
            body = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        for k, v in (headers or {}).items():
            self.send_header(k, v)
        self.end_headers()
        if body:
            self.wfile.write(body)

    def do_GET(self):
        if self.path in ("/", "/index.html"):
            return self._index()
        if self.path.startswith("/img/"):
            return self._img(self.path[len("/img/"):])
        if self.path.startswith("/text/"):
            return self._text(self.path[len("/text/"):])
        if self.path.startswith("/export.csv"):
            return self._export()
        self._send(404, "not found")

    def do_POST(self):
        if self.path.startswith("/copy/"):
            return self._copy(self.path[len("/copy/"):])
        self._send(404, "not found")

    def _index(self):
        rows, ts = cliphist_list(), timestamps()
        cards = []
        for r in rows:
            cid = r["id"]
            stamp = ts.get(cid, "")
            if r["is_img"]:
                body = '<img loading="lazy" src="/img/{}" alt="clipboard image #{}">'.format(
                    html.escape(cid), html.escape(cid)
                )
                content_attr = ""  # images aren't text-searchable
                chip = '<span class="chip chip-image">img</span>'
                typ = "image"
            else:
                text = r["preview"]
                shown = text if len(text) < 600 else text[:600] + " …"
                body = '<div class="txt">{}</div>'.format(html.escape(shown))
                content_attr = html.escape(text.lower(), quote=True)
                chip = '<span class="chip chip-text">txt</span>'
                typ = "text"
            cards.append(
                '<article class="card" tabindex="0" data-id="{cid}" data-type="{typ}" '
                'data-ts="{ts}" data-content="{content}" onclick="openModal(\'{cid}\',\'{typ}\')" '
                "onkeydown=\"if(event.key==='Enter'||event.key===' '){{event.preventDefault();openModal('{cid}','{typ}')}}\">"
                '<div class="card-head"><span class="cid">#{cid}</span>{chip}'
                '<time class="ts">{human}</time>'
                '<button class="ico" type="button" title="Copy" aria-label="Copy" '
                'onclick="event.stopPropagation();copyId(\'{cid}\',this)">{copy}</button>'
                '<button class="ico" type="button" title="Preview" aria-label="Preview" '
                'onclick="event.stopPropagation();openModal(\'{cid}\',\'{typ}\')">{maxi}</button>'
                '</div><div class="body">{body}</div></article>'.format(
                    typ=typ,
                    ts=html.escape(stamp, quote=True),
                    content=content_attr,
                    cid=html.escape(cid),
                    chip=chip,
                    human=html.escape(human_ts(stamp)),
                    body=body,
                    copy=SVG_COPY,
                    maxi=SVG_MAX,
                )
            )
        self._send(200, PAGE.replace("%%CARDS%%", "".join(cards)))

    def _img(self, cid):
        cid = cid.split("/")[0]
        data = decode(cid)
        if not data:
            return self._send(404, "no data")
        self._send(200, data, mime_of(data))

    def _text(self, cid):
        cid = cid.split("/")[0]
        data = decode(cid)
        if not data:
            return self._send(404, "no data")
        self._send(200, data, "text/plain; charset=utf-8")

    def _copy(self, cid):
        cid = cid.split("/")[0]
        data = decode(cid)
        if not data:
            return self._send(404, "no data")
        mime = mime_of(data)
        args = ["wl-copy", "--type", mime] if mime.startswith("image/") else ["wl-copy"]
        subprocess.run(args, input=data)
        self._send(204, b"")

    def _export(self):
        rows, ts = cliphist_list(), timestamps()
        buf = io.StringIO()
        w = csv.writer(buf)
        w.writerow(["id", "timestamp", "type", "content"])
        for r in rows:
            cid = r["id"]
            content = r["preview"] if not r["is_img"] else "[image] " + r["preview"].strip("[] ")
            w.writerow([cid, ts.get(cid, ""), "image" if r["is_img"] else "text", content])
        self._send(
            200,
            buf.getvalue(),
            "text/csv; charset=utf-8",
            {"Content-Disposition": 'attachment; filename="clipboard-history.csv"'},
        )


def main():
    srv = ThreadingHTTPServer((HOST, PORT), Handler)
    print("cliphist viewer on http://{}:{}".format(HOST, PORT), flush=True)
    srv.serve_forever()


if __name__ == "__main__":
    main()
