# cliphist-viewer

Browser DB viewer for the **cliphist** clipboard store. A tiny stdlib
`http.server` (`viewer.py`) that renders every cliphist entry as an HTML grid —
text inline, images as decoded thumbnails — with a filter bar and CSV export.
Loopback-only on `127.0.0.1:8899`.

## Files

| File | Purpose |
|---|---|
| `default.nix` | NixOS **system** service `cliphist-viewer` (not a HM user unit — see "Why a system service"). Runs `viewer.py` as user `killua` with `HOME` / `XDG_RUNTIME_DIR` set and `WAYLAND_DISPLAY` auto-discovered (first `wayland-*` socket) so it can read `~/.cache/cliphist/db` and copy to the live Wayland clipboard. **No `wantedBy`** → installed but never auto-started. `path` provides cliphist, wl-clipboard, file, coreutils. |
| `viewer.py` | The server. Stdlib only (`http.server`, `subprocess`, `csv`). Routes: `GET /` (grid + filter bar), `GET /img/<id>` (decoded image bytes, mime-typed), `GET /text/<id>` (decoded text, `text/plain` — used by the modal so it shows the **full** content with original newlines, not cliphist's newline-collapsed list preview), `GET /export.csv` (download), `POST /copy/<id>` (`wl-copy` the decoded entry back, mime-detected so images copy as images). |

## Why a system service (not `systemd.user.services`)

The Glance **service-bridge** (`modules/containers/service-bridge/`) drives the
Home-page "Services" tile and the Containers-tab start/stop buttons by calling
root's `systemctl` — it **cannot** reach `systemctl --user` units. To be
startable from Glance, this must be a system `.service`. It still needs the
user's clipboard db + Wayland session, so it runs `User = killua` with the
session env wired in by hand.

## Glance wiring

Registered in `service-bridge/services.nix` as `{ name = "Clipboard"; unit =
"cliphist-viewer.service"; url = "http://localhost:8899"; homepage = true; }`.
`homepage = true` puts it on the Home-page "Services" tile (status pill + link);
every entry also appears on the Containers tab with Start/Stop/Restart buttons.
No CDN clipboard icon exists (`si:`/`di:` both 404), so `icon` is a
self-contained base64 SVG data URI — service-bridge only rewrites `si:`/`di:`
prefixes and passes anything else through verbatim as the `<img src>`.

## Timestamps

cliphist records **no** timestamps (its db is an ordered id→content list). Dates
come from a sidecar at `~/.cache/cliphist/timestamps` (`<id>\t<iso8601>` lines)
written by the cliphist watchers in `hyprland/clipboard.nix` — so date filtering
+ the CSV `timestamp` column only cover entries copied **after** that change
shipped; older entries show "—" and are excluded when a date filter is active.

## Card interactions

- **Click a card** (or its maximize/preview icon) → opens a centered **modal**
  with the full content: scrollable, blurred + dimmed backdrop, closes on the X
  button, `Escape`, or a backdrop click. Text is fetched from `/text/<id>`
  (full, newline-preserving); images load `/img/<id>` at full resolution.
- **Copy button** in each card head (beside the timestamp) → `POST /copy/<id>`
  (`stopPropagation`, so it doesn't also open the modal). The modal head has its
  own copy button too. Copy shows a "Copied" toast; the card body itself no
  longer copies on click (that opens the modal now).

## Filter bar

Client-side JS over per-card `data-*` attributes — no server round-trip:
- **Search** (`data-content`, lowercased text; images aren't text-searchable).
- **Type** — all / text / images (`data-type`).
- **Date range** from/to (`data-ts`, compared on the `YYYY-MM-DD` prefix).
- **Clear** resets all; live "N / total shown" count.
- **Export CSV** — `GET /export.csv`, columns `id,timestamp,type,content`
  (image rows emit `[image] <preview>`, not binary). Downloads as
  `clipboard-history.csv` for sharing.
- **Theme** — light/dark via CSS custom properties: defaults to the OS
  (`prefers-color-scheme`), with a toolbar toggle that stamps
  `data-theme` on `<html>` and persists to `localStorage`. Biased-slate
  neutrals + a single indigo accent; `system-ui` for chrome, JetBrainsMono for
  clipboard content/ids/timestamps. No external fonts/CDN (offline-safe).

## Security

The history can contain secrets (e.g. values copied via `clipboard-menu`). The
boundary is loopback-only bind + on-demand start (no autostart). Don't expose
the port.

## Integration

`default.nix` is imported by `modules/containers/default.nix` (both hosts).
Depends on the cliphist store fed by `modules/common/programs/desktop/hyprland/clipboard.nix`
(HM watchers) and is surfaced through `modules/containers/service-bridge/` +
`glance.nix`.
