# Boeing VPN browser-UI

Browser-driven replacement for the terminal `boeingvpn` workflow. A small Python HTTP daemon listens on `127.0.0.1:7777`, fronts `openconnect --protocol=gp --user=<userid> ... --script-tun --script "ocproxy -D 1080" --passwd-on-stdin https://<gateway>`, and serves a static frontend that simulates a single draggable Windows-style window with Connect / Connect-fastest / Disconnect / Reconnect controls, a PIN+token input, an editable **User ID** field, and a **gateway dropdown**.

The userid and gateway are no longer hardcoded:

- **User ID** defaults to the `boeing/vpn_userid` sops secret (the daemon reads the decrypted file at runtime; its path is `replaceVars`-substituted into `daemon.py` as `@useridfile@` from `config.sops.secrets."boeing/vpn_userid".path`). The field is prefilled from `/api/config` and editable per-connect; an empty field falls back to the sops default server-side.
- **Gateway** is chosen from a dropdown populated from the `GATEWAYS` catalog in `daemon.py` (single source of truth, served via `/api/config`). Plain **Connect** uses the selected dropdown entry; **Connect fastest** calls `/api/fastest`, which TCP-probes all gateways concurrently (median of `PROBE_SAMPLES`=5 RTTs to `:443`; TLS skipped — Boeing GP gateways need unsafe legacy renegotiation), preselects the winner in the dropdown, and shows `Fastest: <name> (<ms>)`. `rank_gateways()` enforces a hard `RANK_DEADLINE`=8s wall-clock cap via `as_completed(timeout=…)` + `pool.shutdown(wait=False, cancel_futures=True)` (a plain `with ThreadPoolExecutor` would block on shutdown and blow the cap); a down gateway is dropped after a 2-strike early-exit (`PROBE_TIMEOUT`=2s/connect). The same RTT-probe logic backs the zsh `boeingvpn` function and `gp-fastest-gateway.sh`.

Same `openconnect` + `ocproxy` pair the zsh `boeingvpn` function uses (`modules/common/programs/shells/zsh.nix:148-156`); no privilege escalation because `--script-tun` keeps everything in userspace (no TUN device, ocproxy provides the SOCKS5 listener on `:1080`).

## Second window — Bastion (DB tunnels)

The same fake-desktop page hosts a **second draggable window** ("Boeing Bastion") that drives `bastion all` (`DotFiles/scripts/boeing/bastion.d/bastion-all` — one az bastion tunnel + one `ssh -N` carrying the Oracle/Postgres/Cosmos `-L` forwards). It has **Connect / Disconnect**, a status pill, an in-panel **device-code login** box, and a **credentials table** (Oracle/PG/Cosmos user·pass·url·local-port) parsed live from the bastion env file. Click any credential value to copy it.

- **Connect** → `POST /api/bastion/connect` spawns `bastion all` (background, own process group). The daemon injects `PATH=@bastiontools@` (az + ssh + sshpass + proxychains + coreutils, since a `systemd --user` service doesn't inherit the login-shell PATH), `BASTION_SSH_VIA_SOCKS=1`, and `BASTION_ENV_FILE`. Requires the VPN window to be connected first (az routes through the `:1080` SOCKS listener).
- **Device-code login**: when `bastion all` (→ `ensure_subscription` → `bastion login`) emits `az login --use-device-code`, `_watch` regex-matches the "open the page … enter the code …" line, flips state to `login-required`, and the panel shows the URL + code. You approve in the browser; the daemon keeps running.
- **Connected signal**: `_poll_ports` TCP-connects `127.0.0.1:1521` (the Oracle forward) — bound as soon as ssh is up — and flips to `connected`. Mirrors `VpnManager._poll_socks`.
- **Disconnect** → `POST /api/bastion/disconnect` → `os.killpg(SIGTERM)`. Because `bastion all` ends in `exec ssh`, the backgrounded az tunnel and ssh share the child's process group, so one killpg tears both down (SIGKILL fallback after 6s). **Disconnecting the VPN also stops bastion** — `VpnManager.disconnect` calls `BASTION.disconnect()` (bastion rides the VPN's `:1080` SOCKS listener, so it's dead weight once the VPN drops).
- **`login-required` auto-clears**: `_watch` drops the state back to `connecting` when az moves past the device code (`Retrieving subscriptions`, `[2/3]`, `Opening bastion tunnel`, …), so the "waiting for approval" box doesn't linger after you approve (or when no login was needed).
- **Credentials**: `GET /api/bastion/creds` parses `AZURE_ORACLE_*` / `AZURE_PG_*` / `AZURE_COSMOS_*` out of `~/.config/azure-bastion.env` (override `$BASTION_ENV_FILE`). Loopback-only, same trust model as everything else here. Missing keys render as an italic placeholder.

The `bastion` dispatcher itself is a DotFiles script (not a nix binary): resolved at runtime via `$BASTION_BIN` → `PATH` → `~/killuanix/DotFiles/scripts/boeing/bastion`. Local forward ports (`BASTION_LOCAL_PORTS` = 1521/5433/8443) must match the `LOCAL_*_PORT` defaults in `bastion-all`.

## Files

| File | Description |
|---|---|
| `default.nix` | HM module: builds `boeingvpn-ui` derivation from `daemon.py` + `static/`, installs systemd **user** service `boeingvpn-ui` (autostart on login). Also builds `azCli` (`azure-cli.withExtensions [ssh bastion]`) + `bastionTools` (`lib.makeBinPath` of az/ssh/sshpass/proxychains/coreutils) and substitutes the latter as `@bastiontools@` so the Bastion window can run `bastion all`. Linux-only. |
| `nixos.nix` | NixOS module: writes `/etc/opt/chrome/policies/managed/boeingvpn-ui.json` with a `ManagedBookmarks` policy adding a "Boeing → VPN" bookmark pointing at `http://127.0.0.1:7777/`. System-scope, applies to every Chrome profile (including the chrome-socks `--user-data-dir`). |
| `daemon.py` | Python 3 stdlib HTTP server. VPN endpoints: `GET /api/status`, `GET /api/config`, `GET /api/fastest`, `POST /api/connect {secret, userid, gateway}`, `POST /api/disconnect`, `POST /api/reconnect`. Bastion endpoints: `GET /api/bastion/status`, `GET /api/bastion/creds`, `POST /api/bastion/connect`, `POST /api/bastion/disconnect`. `VpnManager` owns openconnect; `BastionManager` owns `bastion all`. `@var@` placeholders (`@useridfile@`, `@bastiontools@`, …) filled by `pkgs.replaceVars`. |
| `static/index.html` | Fake-desktop page + markup for **both** windows (VPN + Bastion). |
| `static/style.css` | Wallpaper backdrop, Windows-y window chrome, status pill colors, plus Bastion window styles (login box, code chip, credentials table). |
| `static/app.js` | Shared no-library drag (`makeDraggable`, z-index raise) for both windows, VPN + Bastion state machines, fetch wiring, click-to-copy, 2s status polls. |
| `static/wallpaper.svg` | Static blue gradient + faint 747 silhouette; shipped to avoid any external fetch. |

## State machine

Daemon state (server-side, in `daemon.py`'s `VpnManager`):

```
idle → connecting → connected      (when openconnect prints "Connected as …")
                  → error          (subprocess exits non-zero)
connected → disconnecting → idle   (after SIGTERM / wait / SIGKILL fallback)
```

`BastionManager` (second window) state:

```
idle → connecting → connected            (127.0.0.1:1521 forward bound)
                  → login-required        (az device code emitted; code+url shown)
                  → error                 (bastion all exits non-zero)
login-required → connected               (once tunnels come up)
connected → disconnecting → idle          (killpg the process group)
```

Frontend adds two UI-only states the daemon has no concept of: `awaiting-secret` (between pressing Connect and submitting the secret) and `probing` (while Connect-fastest runs `/api/fastest`). The 2s status poll explicitly does not overwrite either.

Status pill colors:

| UI state | Dot | Buttons |
|---|---|---|
| idle / disconnected | grey | Connect + Connect-fastest on |
| probing | yellow (pulsing) | all buttons off until probe returns |
| awaiting-secret | yellow (pulsing) | input + arrow on, userid/gateway editable, Disconnect doubles as Cancel |
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
- Last submitted secret **plus userid + gateway** are cached in-memory only (for Reconnect). Never persisted to disk. The userid default originates from sops but is sent by the browser per-connect like any other field.

## Lifecycle

- `systemd --user` unit `boeingvpn-ui.service`, `Restart=on-failure`, `WantedBy=default.target` (autostarted on login).
- `KillMode=control-group` so a stop or restart of the unit also kills any in-flight openconnect+ocproxy.
- Logs: `journalctl --user -u boeingvpn-ui`.

## Integration

- HM side: imported from `modules/common/programs.nix` → propagates to every Home Manager configuration in this flake (chrollo, killua, archnix, macnix). Self-gates via `lib.optionals pkgs.stdenv.isLinux` and `lib.mkIf pkgs.stdenv.isLinux`, so the Darwin build skips the systemd unit naturally.
- NixOS side: `nixos.nix` is imported directly from `chrollo/configuration.nix` and `killua/configuration.nix`. Hosts that don't need the bookmark simply skip the import.
- archnix has no NixOS layer; if the bookmark is wanted there, drop the same JSON into `/etc/opt/chrome/policies/managed/` via aconfmgr or a system-manager module.
