# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal Nix flake configuration managing multiple target platforms from a single repo:

- **NixOS desktop** (`nixosConfigurations.chrollo` + standalone `homeManagerConfigurations.chrollo`) — system and Home Manager are **separate switches** (NixOS module integration was removed; run `nixos-rebuild` and `home-manager` independently)
- **NixOS handheld** (`nixosConfigurations.killua` + standalone `homeManagerConfigurations.killua`) — MSI Claw / handheld variant on Jovian-NixOS + CachyOS kernel; same split system/HM setup as chrollo
- **Arch Linux** (`homeManagerConfigurations.archnix`) — standalone Home Manager on Arch, uses `nixGL` for GPU wrapping and `aconfmgr` for native package tracking
- **macOS** (`darwinConfigurations.macnix`) — nix-darwin with Home Manager wired in via the Darwin module (unified switch)

## Build / Apply Commands

```bash
# NixOS desktop (chrollo) — system and home are separate switches
sudo nixos-rebuild switch --flake .#chrollo
home-manager switch --flake .#chrollo

# NixOS handheld (killua, MSI Claw)
sudo nixos-rebuild switch --flake .#killua
home-manager switch --flake .#killua

# Arch Linux — standalone Home Manager
nix build '.#homeManagerConfigurations.archnix.activationPackage' && ./result/activate
# or, if home-manager CLI is available:
home-manager switch --flake '.#archnix'

# macOS
darwin-rebuild switch --flake .#macnix

# Format all nix files (alejandra)
nix fmt
```

## Post-install setup

The flake auto-bootstraps most services, but a few one-shot manual steps remain after a fresh NixOS install:

- **Cockpit** (`modules/containers/cockpit.nix`) — web GUI for systemd + podman on http://localhost:9091 (loopback only, `cockpit.socket` `mkForce`d off 0.0.0.0). Covers every unit on the host with status, start/stop/restart, live journalctl, and a Containers tab via `cockpit-podman` against the rootful quadlet socket. No bootstrap: login is local-user PAM (the `killua` user must have a password set via `passwd` — SSH-key-only accounts can't reach the UI). Complements `service-bridge` (curated allowlist → Glance tiles) rather than replacing it; Cockpit also appears as a Glance tile via `service-bridge/services.nix`.
- **Karakeep** (`modules/containers/karakeep.nix`) — bookmark + read-later + AI tagging app on http://localhost:9090, backed by an internal Meilisearch container. `autoStart = false` on both; bring them up manually (`sudo systemctl start karakeep karakeep-meili`). The admin user is seeded on the first boot of a fresh `karakeep_data` volume by `karakeep-bootstrap.service` — it POSTs `karakeep_admin_email` + `karakeep_admin_password` (sops) to Karakeep's tRPC `users.create` endpoint, marks `/var/lib/karakeep/.admin-seeded`, and never re-runs. Rotating those sops values won't change the running password (rebuild the volume to re-seed, or change in UI). `karakeep-import.service` + `.timer` (daily) decrypt `secrets/karakeep-bookmarks.html` (Netscape HTML export) and bulk-create bookmarks into an `Imported from sops` list — additive only (Karakeep dedupes by URL; removed URLs are not auto-deleted). Requires `karakeep_admin_api_key` in sops (generate it in the UI after first login). Other sops keys: `karakeep_nextauth_secret`, `karakeep_meili_master_key` (both `openssl rand -hex 32`), and `karakeep_openai_api_key` for AI auto-tagging.
- **Cronicle** (`modules/containers/cronicle/`) — declarative cron with web UI on http://localhost:3012. Events are individual `.nix` files under `cronicle/events/`, each with an `enabled` flag. Sync runs in two systemd units: `cronicle-init.service` (one-shot, before `cronicle.service`) runs `control.sh setup` against the data volume via an ephemeral `podman run` while the daemon is offline (idempotent: gated by `/var/lib/cronicle/.setup-done`) so the default admin user + categories + plugins exist; `cronicle-bootstrap.service` then POSTs `admin`/`admin` to `/api/user/login` to obtain a `session_id` and talks to the running Cronicle over `/api/app/update_event/v1` (with a `create_event/v1` fallback) to push each event. `enabled = true` posts `enabled: 1` (Active checkbox on), `enabled = false` posts `enabled: 0` so the event stays visible but greyed out / not firing. Per-event state at `/var/lib/cronicle/state/<id>` makes the sync idempotent — UI pauses on active-in-nix events survive rebuilds because the sentinel matches and we don't re-touch. Flipping `enabled` in nix re-pushes the event, which intentionally clobbers any UI edits to that event's params (the toggle is the source of truth on rebuild). Default login is `admin`/`admin` — **do not rotate the admin password via the UI**, or the bootstrap login will break; if you need to rotate it, plumb the new password through sops and update the login body in `modules/containers/cronicle/default.nix`. Live + completed logs in Job Details / Completed Jobs tabs.
- **FreshRSS** (`modules/containers/freshrss/`) — self-hosted RSS aggregator on http://localhost:8083 (127.0.0.1-only). Single quadlet container backed by SQLite in the `freshrss_data` volume (extensions live in `freshrss_extensions`, plus a read-only nix-built bundle at `/var/www/FreshRSS/extensions/nix` selected by `extensions.nix`). `autoStart = true`. Admin user (`killua`) is auto-seeded by the upstream image's entrypoint on the first boot of an empty data volume using `ADMIN_USERNAME` / `ADMIN_EMAIL` (inline) + `ADMIN_PASSWORD` / `ADMIN_API_PASSWORD` (sops via `freshrss-env.service` → `/run/freshrss/env`). Rotating `freshrss_admin_password` in sops will NOT change the running web-login password (wipe the volume or change in the UI), but rotating `freshrss_admin_api_password` **does** propagate — `freshrss-bootstrap-api-pw.service` re-applies it on every rebuild via `cli/update-user.php`. Per-user prefs (theme, view, sort, archiving, extension activation, sharing destinations, saved searches) are declarative in `bootstrap.nix`'s `userConfig` attrset; the file is hash-gated so flipping a value re-applies on the next switch and `array_replace_recursive` preserves auth-bearing fields the UI manages. OPML feed list is opt-in via `opml.nix` (set `cfg.enable = true`, add `freshrss_opml` multi-line scalar to sops); imports on boot + daily timer, idempotent + additive. Feeds refresh every 15 min via the container's internal cron (`CRON_MIN=*/15`). Desktop client (`rssguard`) is wired declaratively in `modules/common/programs/rss/` — `config.ini` rendered from nix, optional one-shot SQLite seed for the FreshRSS account. Full runbook + toggles in `modules/containers/freshrss/CLAUDE.md` and `modules/common/programs/rss/CLAUDE.md`.
- **Speedtest Tracker** (`modules/containers/speedtest-tracker.nix`) — scheduled Ookla speedtests + REST API on http://localhost:8765 (linuxserver image). Default schedule every 6h, 30-day retention. `autoStart = false` (start manually: `sudo systemctl start speedtest-tracker`). **Before first boot** set `speedtest_tracker_app_key` in sops (`openssl rand -base64 32`; if this rotates, stored history becomes unreadable). On first boot log in with `admin@example.com` / `password`, change the password, then Settings → API tokens → "Create token" → paste into sops as `speedtest_tracker_api_token` and `sudo systemctl restart glance-env glance` so the Home-page "Internet" widget can read it. Trigger an immediate test with `sudo podman exec speedtest-tracker php /app/www/artisan speedtest:run`. The container uses `publishPorts` (not host network) because the linuxserver image's nginx is locked to :80 — glance reads it over the host loopback since glance itself runs on `networks = ["host"]`.
- **Trakt + TMDB media widgets** (`modules/containers/glance.nix` Home page) — "recently watched", trending movies + shows, and upcoming movie/TV calendars are driven by Trakt with TMDB poster enrichment. Trending widgets need only `trakt_api_key` (the OAuth app's Client ID from https://trakt.tv/oauth/applications) and `tmdb_api_key` (themoviedb.org). The personal calendars + history widgets additionally need an OAuth Bearer token: register the Trakt app with redirect URI `urn:ietf:wg:oauth:2.0:oob`, then run `TRAKT_CLIENT_ID=... TRAKT_CLIENT_SECRET=... scripts/trakt-auth.sh` (device flow — opens trakt.tv/activate, polls for approval, prints `access_token`). Paste the access token into sops as `trakt_access_token`, plus `trakt_username` (plaintext). Access tokens expire after ~3 months — re-run the script and rotate. No automated refresh service.
- **Matrix stack** (`modules/containers/matrix/`) — Synapse + four mautrix bridges (Telegram / WhatsApp / Instagram / Messenger) + Element Web. `server_name = matrix.killua.local`, federation off, only `127.0.0.1:8008` (Synapse) and `127.0.0.1:8009` (Element Web) reach the host. All 7 containers ship with `autoStart = false` — start manually with `sudo systemctl start synapse element-web mautrix-telegram mautrix-whatsapp mautrix-meta-instagram mautrix-meta-messenger` (synapse cascades postgres + overrides + bridge-config oneshots via Requires). Before first `nixos-rebuild switch` you must populate ~20 keys in `secrets/personal.yaml` (per-bridge `as_token`/`hs_token`/`pickle_key`/`db_password`, plus Telegram `api_id`/`api_hash` from https://my.telegram.org). After it's up: `sudo podman exec -it synapse register_new_matrix_user -c /data/homeserver.yaml -c /etc/synapse/overrides.yaml -u akshay -a http://localhost:8008` → log in to Element Web at http://127.0.0.1:8009 → DM each `@*bot:matrix.killua.local` to authenticate the bridge. Full bootstrap walkthrough + pitfalls in `modules/containers/matrix/CLAUDE.md`.
- **Boeing modernization infra** — local-dev databases backing the microservices in `~/Documents/Boeing/modernization/`. Five containers on localhost: `boeing-mongo` (`:27017`, root/root), `boeing-mongo-express` (`:8181`), `boeing-redis` (`:6379`, AOF on), `boeing-redis-commander` (`:8281`), `boeing-postgres` (`:5432`, boeing/boeing). The day-to-day path is **docker compose**, driven by the Justfile at `~/Documents/Boeing/modernization/`: `just up`/`just down` bring up two stacks under project name `boeing` — the mongo+redis+UIs stack prefers `sh-usermgmt-api/develop/docker-compose.yml` and falls back to `docker-compose.yml` at the modernization root when that worktree isn't cloned; postgres always runs from `docker-compose.postgres.yml` (no per-service file exists). Volumes are docker-managed (`boeing_mongo_data`, `boeing_redis_data`, `boeing_pg_data`); `just reset-mongo` wipes mongo's volume so `/docker-entrypoint-initdb.d/` scripts re-run. The matching nix quadlets at `modules/containers/boeing/` (`autoStart = false` on all five) are kept as an alternative path but are no longer driven by `just up` — their volumes are separate from the compose-managed ones, so the two mechanisms shouldn't be run interchangeably without a manual data dump. Java 25 + Maven + Just live in a per-project devShell at `~/Documents/Boeing/modernization/flake.nix` (auto-loaded via direnv); other recipes: `just bootstrap` builds `sh-platform-starter`, `just usermgmt run` runs the user-mgmt service against the local infra, `just which-compose` shows which compose file is currently active.

## Architecture

### Flake outputs

| Output | Entry point | Description |
|---|---|---|
| `nixosConfigurations.chrollo` | `chrollo/configuration.nix` | Desktop NixOS system config (system-only; HM lives in `homeManagerConfigurations.chrollo`) |
| `nixosConfigurations.killua` | `killua/configuration.nix` | Handheld/MSI Claw NixOS variant (Jovian + CachyOS kernel); system-only |
| `homeManagerConfigurations.chrollo` | `chrollo/home-manager/home.nix` | Standalone HM for the chrollo host |
| `homeManagerConfigurations.killua` | `killua/home.nix` | Standalone HM for the killua host |
| `homeManagerConfigurations.archnix` | `archnix/home.nix` | Standalone HM for Arch Linux |
| `darwinConfigurations.macnix` | `macnix/default.nix` | nix-darwin system + HM |
| `systemConfigs.default` | `archnix/system-manager.nix` | `system-manager` config for Arch (container registry, podman, lingering) |

### Module layers

- **`modules/common/`** — pure data and Home Manager modules shared by all platforms
  - `user.nix` — canonical user config (username, email, SSH keys, session vars) referenced as `inputs.self.commonModules.user.userConfig`
  - `packages.nix` — package sets (`commonPackages`, `terminalPackages`, `desktopPackages`, `devPackages`, `macPackages`) consumed by `cross-platform/default.nix`
  - `programs.nix` — imports all per-program HM modules (kitty, git, hyprland, neovim, firefox, etc.)
  - `mcp-servers.nix` — declarative MCP server catalog (shared by Claude / OpenCode configs via `mcp-servers-nix`)
  - `sops.nix` / `sops-system.nix` — sops-nix secret declarations (HM and NixOS-system scopes)
- **`modules/cross-platform/default.nix`** — the main Home Manager entrypoint imported by every platform; assembles packages, sops, programs, theming, and platform-conditional logic (`stdenv.isLinux` / `isDarwin`)
- **`modules/common/programs/`** — individual program configs organized by category, each with its own `CLAUDE.md`:
  - [`audio/CLAUDE.md`](modules/common/programs/audio/CLAUDE.md) — PipeWire/WirePlumber tuning, Bluetooth audio, Spotify (spicetify-nix)
  - [`boeingvpn-ui/CLAUDE.md`](modules/common/programs/boeingvpn-ui/CLAUDE.md) — Browser-driven Boeing VPN: tiny Python daemon on 127.0.0.1:7777 fronting openconnect+ocproxy, fake-Windows page with draggable window. NixOS half drops a Chrome `ManagedBookmarks` policy on chrollo+killua.
  - [`browsers/CLAUDE.md`](modules/common/programs/browsers/CLAUDE.md) — Firefox (Arkenfox + Natsumi), Qutebrowser → [`firefox/CLAUDE.md`](modules/common/programs/browsers/firefox/CLAUDE.md)
  - [`desktop/CLAUDE.md`](modules/common/programs/desktop/CLAUDE.md) — Hyprland, Satty, desktop entries → [`hyprland/CLAUDE.md`](modules/common/programs/desktop/hyprland/CLAUDE.md)
  - [`dev/CLAUDE.md`](modules/common/programs/dev/CLAUDE.md) — Git, Lazygit → [`ai/CLAUDE.md`](modules/common/programs/dev/ai/CLAUDE.md) (Claude Code + bundled skills, OpenCode, ccmanager, ccr, ruflo, claude-flow, claude-kit, code-index, jupyter-env MCP)
  - [`diagrams/CLAUDE.md`](modules/common/programs/diagrams/CLAUDE.md) — Excalidraw / Mermaid Live launchers, mermaid-cli, `text/vnd.mermaid` MIME wiring
  - [`editors/CLAUDE.md`](modules/common/programs/editors/CLAUDE.md) — Neovim (nixCats), Zed → [`neovim/CLAUDE.md`](modules/common/programs/editors/neovim/CLAUDE.md)
  - [`mail/CLAUDE.md`](modules/common/programs/mail/CLAUDE.md) — Thunderbird with a manually-packaged add-on bundle
  - [`media/kodi/CLAUDE.md`](modules/common/programs/media/kodi/CLAUDE.md) — Kodi media center, Arctic Fuse skin, custom addons, Real-Debrid integration
  - [`notes/CLAUDE.md`](modules/common/programs/notes/CLAUDE.md) — Obsidian vault config (NixOS-only: chrollo + killua)
  - [`openchamber/CLAUDE.md`](modules/common/programs/openchamber/CLAUDE.md) — OpenChamber Web GUI package
  - [`rss/CLAUDE.md`](modules/common/programs/rss/CLAUDE.md) — RSSGuard desktop reader, declarative `config.ini`, optional FreshRSS account seed
  - [`shells/CLAUDE.md`](modules/common/programs/shells/CLAUDE.md) — Zsh, Fish, Starship prompt
  - [`terminal/CLAUDE.md`](modules/common/programs/terminal/CLAUDE.md) — Ghostty (primary under Hyprland), Kitty, Zellij
  - [`theming/CLAUDE.md`](modules/common/programs/theming/CLAUDE.md) — Shared `config.theme.palette`, GTK/libadwaita CSS, Kvantum + qt5ct/qt6ct
  - [`utils/CLAUDE.md`](modules/common/programs/utils/CLAUDE.md) — Yazi, Zathura, Nemo, mimeapps, clipboard-menu, dotfile symlinks → [`yazi/CLAUDE.md`](modules/common/programs/utils/yazi/CLAUDE.md)
- **`modules/containers/`** — quadlet / portainer container definitions (litellm, mcphub, qdrant, searxng, portainer, glance, excalidraw, mermaid-live, karakeep, icloud-drive, cronicle, boeing, matrix → [`matrix/CLAUDE.md`](modules/containers/matrix/CLAUDE.md), freshrss → [`freshrss/CLAUDE.md`](modules/containers/freshrss/CLAUDE.md))
- **`modules/vms/`** — libvirt/qemu VM definitions and plugins (activity-sim, work-vm, vm-manager)
- **`modules/nixos/`**, **`modules/home-manager/`** — thin module entry points re-exported via the flake's `nixosModules` / `homeManagerModules`

### Platform-specific directories

- `chrollo/` — desktop NixOS system config + hardware config; `chrollo/home-manager/home.nix` adds NixOS-only HM modules and packages
- `killua/` — MSI Claw / handheld NixOS config (boot, gaming, hhd, intel-gpu, wifi-fix, handheld-tweaks) with its own `home.nix`
- `archnix/` — Arch-specific HM config; wraps Hyprland and Zed with `nixGL`; includes `aconfmgr/` submodule for Arch package tracking, plus `packages/` and `users/` subdirs
- `macnix/` — Darwin system settings, Homebrew casks (`brew.nix`), macOS-specific packages
- `overlays/`, `packages/` — custom nixpkgs overlays and standalone derivations consumed via `self.customOverlays` / direct imports
- `scripts/`, `sdethings/`, `Notes/` — ad-hoc scripts and notes

### Nix runtime

**chrollo** and **killua** run **Determinate Nix** (`inputs.determinate.nixosModules.default` imported via `flake.nix` → `nixosConfigurations.<host>`). It replaces the upstream daemon with the Determinate fork. Key wins active by default:

- `lazy-trees` — skips fetching/realising unused flake inputs at eval time. **Top-level config option**, not an experimental feature — `nix show-config | grep lazy-trees` reports `true` on a fresh Determinate install. Do NOT add it to `experimental-features` (warns "unknown experimental feature").
- Parallel daemon marshalling — internal, no knob to flip.

Because both are on automatically, `nix.settings.experimental-features` stays at `"nix-command flakes"` and `scripts/nix_switch` only injects `eval-cache = true` via `NIX_CONFIG` (defensive — already default since Nix 2.4). The script's runtime detection (`nix --version` matching `*Determinate*` / `*Lix*`) is used solely to log which speedups are live.

`nh` (nix-helper) is wired into `commonPackages` and used by `nix_switch` for `nh os switch` / `nh home switch` — gives a colored closure diff before activation. Falls back to raw `nix build` / `nixos-rebuild` automatically when `nh` is absent (e.g. first run after a fresh install).

### Secrets

Managed with **sops-nix** + **age** encryption. Keys defined in `.sops.yaml`; encrypted secrets live in `secrets/personal.yaml`. The age key file is expected at `~/.config/sops/age/keys.txt`.

### Submodules

- `DotFiles/` — raw dotfiles (firefox configs, quickshell, scripts, etc.) symlinked into place by `dots.nix` and platform-specific `dots-manage.nix`
- `archnix/aconfmgr/` — aconfmgr configuration for Arch native package tracking

## Key Conventions

- The formatter is **alejandra** (`nix fmt`). Run it before committing nix changes.
- User identity and shared session variables are centralized in `modules/common/user.nix` — do not hardcode username/email elsewhere.
- Package lists in `modules/common/packages.nix` are split by category and combined in `cross-platform/default.nix` with platform guards.
- The `DotFiles` submodule is referenced via `${config.home.homeDirectory}/killuanix/DotFiles` for symlinking.

## CLAUDE.md maintenance policy

Every documented directory under `modules/common/programs/` (and the repo root) ships a `CLAUDE.md` that describes its files, notable settings, and integration points. These files must stay in sync with the code — when they drift, future sessions get misled.

**When editing `.nix` files in this repo, you must:**

1. **Update the nearest `CLAUDE.md`** if the change adds/removes/renames a file, changes a documented option or keybinding, changes platform gating (`isLinux`/`isDarwin`/`mkIf`), changes imports, or alters behavior described in the doc. Don't restate implementation details that are obvious from the code — keep the doc focused on *what the module does*, *why it's wired that way*, and *the non-obvious gotchas*.
2. **Create a new `CLAUDE.md`** when you add a new subdirectory under `modules/common/programs/` (or any other place where siblings already have one). Match the style of adjacent docs: H1 title, short overview, `## Files` table, detail sections for notable behavior, closing `## Integration` section naming the import path up to `modules/cross-platform/default.nix` (or the chrollo/killua/archnix/macnix entry point if it's not cross-platform).
3. **Update this root `CLAUDE.md`** — the "individual program configs" list above — whenever you add or remove a module-level `CLAUDE.md`, so the index stays complete.
4. **Do not create `CLAUDE.md` files for directories that don't warrant them** (single-file modules whose source is self-explanatory, or purely-data directories like `templates/`). Prefer extending a parent `CLAUDE.md` with a short subsection.

The goal is that a future Claude Code session can orient itself from the docs alone without re-reading every `.nix` file. If after a change the `CLAUDE.md` in that directory would still be accurate, no update is needed — but verify, don't assume.
