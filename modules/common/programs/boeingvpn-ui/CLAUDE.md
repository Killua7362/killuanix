# Boeing VPN browser-UI

Browser-driven replacement for the terminal `boeingvpn` workflow. A small Python HTTP daemon listens on `127.0.0.1:7777`, fronts `openconnect --protocol=gp ... --script-tun --script "ocproxy -D 1080" --passwd-on-stdin https://ta.as2.cbc.vpn.boeing.net`, and serves a static frontend that simulates a single draggable Windows-style window with Connect / Disconnect / Reconnect controls and a PIN+token input.

Same `openconnect` + `ocproxy` pair the zsh `boeingvpn` function uses (`modules/common/programs/shells/zsh.nix:148-156`); no privilege escalation because `--script-tun` keeps everything in userspace (no TUN device, ocproxy provides the SOCKS5 listener on `:1080`).

## Files

| File | Description |
|---|---|
| `default.nix` | HM module: builds `boeingvpn-ui` derivation from `daemon.py` + `static/`, installs systemd **user** service `boeingvpn-ui` (autostart on login). Linux-only. |
| `nixos.nix` | NixOS module: writes `/etc/opt/chrome/policies/managed/boeingvpn-ui.json` with a `ManagedBookmarks` policy adding a "Boeing → VPN" bookmark pointing at `http://127.0.0.1:7777/`. System-scope, applies to every Chrome profile (including the chrome-socks `--user-data-dir`). |
| `daemon.py` | Python 3 stdlib HTTP server. Endpoints: `GET /api/status`, `POST /api/connect {secret}`, `POST /api/disconnect`, `POST /api/reconnect`. `@var@` placeholders are filled by `pkgs.substituteAll` in `default.nix`. |
| `static/index.html` | Fake-desktop page + window markup. |
| `static/style.css` | Wallpaper backdrop, Windows-y window chrome, status pill colors. |
| `static/app.js` | Drag implementation (no library), state machine, fetch wiring, 2s status poll. |
| `static/wallpaper.svg` | Static blue gradient + faint 747 silhouette; shipped to avoid any external fetch. |

## State machine

Daemon state (server-side, in `daemon.py`'s `VpnManager`):

```
idle → connecting → connected      (when openconnect prints "Connected as …")
                  → error          (subprocess exits non-zero)
connected → disconnecting → idle   (after SIGTERM / wait / SIGKILL fallback)
```

Frontend adds one extra UI-only state, `awaiting-secret`, that lives between the user pressing Connect and submitting the secret (the daemon has no concept of that — it only spawns openconnect on submit). The 2s status poll explicitly does not overwrite `awaiting-secret`.

Status pill colors:

| UI state | Dot | Buttons |
|---|---|---|
| idle / disconnected | grey | Connect on |
| awaiting-secret | yellow (pulsing) | input + arrow on, Disconnect doubles as Cancel |
| connecting / disconnecting | yellow (pulsing) | Disconnect on |
| connected | green | Disconnect + Reconnect on |
| error | red, error line below | Connect + Reconnect on, error stderr tail shown |

## Bookmark gotchas

- `ManagedBookmarks` shows under a **"Managed bookmarks"** folder on the bookmarks bar, not at the root. That is Chrome enterprise-policy behavior, not a bug.
- Policy applies to the `google-chrome` binary; the `chrome-socks` zsh fn at `modules/common/programs/shells/zsh.nix:158-165` just swaps `--user-data-dir`, so the same managed entry shows up in that profile too.
- For Chromium specifically, the policy directory is `/etc/chromium/policies/managed/` instead of `/etc/opt/chrome/policies/managed/`. Only the latter is configured here because the user runs `google-chrome`.

## Privilege model

- Daemon runs as the user — `--script-tun` means no TUN device, no `CAP_NET_ADMIN`, no sudo.
- `openconnect` is invoked with `--passwd-on-stdin`; the daemon writes `PIN+token\n` to stdin once and immediately closes it.
- `ocproxy` is reached via `PATH` (the daemon prepends the ocproxy bin dir before exec), as required by `openconnect --script`.
- Last submitted secret is cached in-memory only (for Reconnect). Never persisted to disk.

## Lifecycle

- `systemd --user` unit `boeingvpn-ui.service`, `Restart=on-failure`, `WantedBy=default.target` (autostarted on login).
- `KillMode=control-group` so a stop or restart of the unit also kills any in-flight openconnect+ocproxy.
- Logs: `journalctl --user -u boeingvpn-ui`.

## Integration

- HM side: imported from `modules/common/programs.nix` → propagates to every Home Manager configuration in this flake (chrollo, killua, archnix, macnix). Self-gates via `lib.optionals pkgs.stdenv.isLinux` and `lib.mkIf pkgs.stdenv.isLinux`, so the Darwin build skips the systemd unit naturally.
- NixOS side: `nixos.nix` is imported directly from `chrollo/configuration.nix` and `killua/configuration.nix`. Hosts that don't need the bookmark simply skip the import.
- archnix has no NixOS layer; if the bookmark is wanted there, drop the same JSON into `/etc/opt/chrome/policies/managed/` via aconfmgr or a system-manager module.
