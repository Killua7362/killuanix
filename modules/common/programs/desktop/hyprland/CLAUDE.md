# Hyprland Module

Hyprland 0.55+ native-Lua configuration. The user-side config (keybinds, rules, env, layout, gestures, leader submap, startup execs) lives as plain `.lua` files under `lua/`. Lock screen, idle daemon, and clipboard watchers stay as nix modules because they configure separate binaries (`hyprlock`, `hypridle`, systemd user services), not Hyprland itself. DMS (DankMaterialShell) is unrelated — see `dms/CLAUDE.md`.

## Why Lua, not nix-attrset → hyprland.conf?

- **LSP / autocomplete.** Hyprland ships EmmyLua stubs at `${hyprland}/share/hypr/stubs/hl.meta.lua`. With a `.luarc.json` next to `hyprland.lua`, `lua-language-server` knows every `hl.config` key, `hl.dsp.*` dispatcher signature, rule field, etc. Nix attrsets are opaque strings.
- **Live editing.** `xdg.configFile."hypr/hyprland.lua"` is a `mkOutOfStoreSymlink` pointing at this directory's `lua/hyprland.lua`. Edits in the repo apply via Hyprland's autoreload — no `nix_switch` round-trip.
- **Real code paths.** Keybinds that previously needed an inline `pkgs.writeShellScript` (column-resize state, leader submap rendering) now run as upvalue-state Lua functions inside Hyprland itself.

## Files

| File | Purpose |
|---|---|
| `default.nix` | Wiring only. Disables the home-manager Hyprland module (so it doesn't write `hyprland.conf`), symlinks the lua stubs to `~/.local/share/hypr/stubs`, writes the `.luarc.json` next to `hyprland.lua`, sources hm-session-vars.sh into `~/.config/uwsm/env`, writes the static LeaderHud metadata JSON, and installs the `hypr-toggle-col-width` shell helper. |
| `lua/hyprland.lua` | Entry point loaded by Hyprland. Extends `package.path` then `require()`s the sibling modules in order (env → general → misc → layout → input → device-gestures → rules → execs → leader → keybinds.register). |
| `lua/.luarc.json` | LSP config so opening the lua tree directly in Neovim/Zed picks up the stubs. The same JSON is also dropped at `~/.config/hypr/.luarc.json` from nix for buffers opened via the symlink. |
| `lua/env.lua` | `hl.config{ env = { … } }`. Fcitx + Wayland/XDG session ids + Qt theming + accessibility flags. |
| `lua/general.lua` | `hl.config{ general = { … } }`. Scrolling layout, border colors, gaps, snap, tearing. |
| `lua/misc.lua` | `hl.config{ misc, xwayland, plugin, animations }` + `hl.animation` calls to disable every leaf. |
| `lua/layout.lua` | `hl.config{ dwindle, decoration, binds, cursor, master, scrolling }`. |
| `lua/input.lua` | `hl.config{ input.touchpad }`. Currently sets `scroll_factor = 0.6` (two-finger scroll speed; lower = slower). |
| `chrollo/home-manager/device-gestures.lua` | **Per-host** touchpad gestures + multi-finger swipe/pinch dispatchers (ThinkPad). Loaded via `try_require("device-gestures")` and symlinked from `chrollo/home-manager/home.nix`. killua (handheld) ships none — no shared `lua/gestures.lua` any more, so its small trackpad doesn't fire workspace-swipe/pinch. |
| `chrollo/home-manager/device-keybinds.lua` | **Per-host** keybinds. Loaded via `try_require("device-keybinds")` and symlinked from `chrollo/home-manager/home.nix`. Currently a single `long_press` bind on `XF86PowerOff` → DMS power menu (`dms ipc call powermenu open`); pairs with logind `HandlePowerKey=suspend` for short-press suspend (locked first via DMS `lockBeforeSuspend`, `chrollo/power.nix`). killua/archnix ship none. |
| `lua/rules.lua` | `hl.window_rule` / `hl.layer_rule` / `hl.workspace_rule` calls. PiP, file dialogs, blueman, Zotero, Kodi, JetBrains Xwayland popups, quickshell namespace blur/animation. |
| `lua/keybinds.lua` | Flat data table `M.binds` of every keybind + `M.register()` walker. Action helpers (`A.focus_dir`, `A.swap_dir`, `A.move_ws`, `A.layout`, …) build dispatchers lazily so the module loads without `hl` defined. Flag mapping in the header comment. |
| `lua/leader.lua` | `hl.define_submap("leader", …)` + the trigger bind. Writes `~/.cache/leader-hud/state` on enter/exit for the LeaderHud DMS bar plugin. Add more submaps by extending the `submaps` table. |
| `lua/execs.lua` | `hl.on("hyprland.start", …)` with `uwsm app --` wrappers (hyprpolkitagent, nm-applet, blueman-applet). **DMS is not here** — it runs as a systemd user service (`programs.dank-material-shell.systemd.enable`, `dms/default.nix`) so it auto-restarts after a Wayland object-registry desync (the `wl_display: invalid object` death that a monitor-hotplug flap triggers across all clients; see Monitors). Sunshine autostart is disabled (start manually). |
| `lua/ws-external.lua` | Shared helper module. `require("ws-external").setup("eDP-1")` registers a `monitor.added` handler that moves workspaces 1-6 onto whatever external connects (port-agnostic). Called from each per-host `device-monitors.lua`. |
| `clipboard.nix` | Systemd user services `cliphist-text` / `cliphist-image` running `wl-paste --watch` over a `cliphist-store-stamped` helper — `cliphist store`, then append `<newest-id>\t<iso8601>` to `~/.cache/cliphist/timestamps`. Backend store for the `clipboard-history` wofi picker (Super+V, `modules/common/programs/utils/clipboard-history.nix`) and the `cliphist-viewer` web UI (`modules/containers/cliphist-viewer/`); the timestamp sidecar is what gives the viewer its date filter + CSV `timestamp` column (cliphist keeps no timestamps of its own). `Restart=always` + `KillMode=mixed`. (The old `qs ipc call cliphistService update` ping was dropped — DMS doesn't consume cliphist.) |
| `hypridle.nix` | Idle daemon, **host-aware** via the `hostName` specialArg. **chrollo**: locks after 300s idle (`on-timeout = loginctl lock-session`) and keeps the display **on** — no DPMS off. **killua/archnix**: original behavior — screen off after 5400s with DPMS on/off on transitions. `lock_cmd` runs the **DMS** locker (`dms ipc call lock lock`, same as Super+L / DMS `loginctlLockIntegration`), falling back to `hyprlock` only if `dms` is absent — deliberate so a `loginctl lock-session` (the chrollo idle listener, or `HandleLidSwitch=lock` on lid close, see `chrollo/power.nix`) doesn't spawn a second ext-session-lock client racing DMS. **Must use the Lua dispatcher form** `hyprctl dispatch 'hl.dsp.dpms("on")'` — Hyprland 0.55+ evals the dispatch arg as Lua, so the bare `hyprctl dispatch dpms on` string fails with `')' expected near 'on'` (DPMS-on after resume silently no-ops). |
| `hyprlock.nix` | Lock screen: blurred Sung Jinwoo wallpaper, centered Rubik clock/date, bottom input field. |
| `dms/` | Modular DankMaterialShell config (Wayland shell, unrelated to hyprlang). See [`dms/CLAUDE.md`](dms/CLAUDE.md). |

## Reload model

Hyprland watches `~/.config/hypr/hyprland.lua` (the symlink target). Saving any `.lua` file under `lua/` triggers autoreload — no nixos-rebuild, no home-manager activation. Trigger one manually with `hyprctl reload`.

Changes that DO require `home-manager switch` (because they cross the nix boundary):
- Adding/removing a `.lua` file (the entry point's `require()` calls live in the file, so a rebuild isn't strictly needed unless the new file should be required — same applies in reverse).
- Editing `default.nix` (stubs symlink target, .luarc.json contents, leader-hud metadata, shell helper script body).
- Editing `clipboard.nix` / `hypridle.nix` / `hyprlock.nix` (these are still nix modules).

## LSP autocomplete

Stubs live at `~/.local/share/hypr/stubs/hl.meta.lua` after a rebuild — a symlink into the active hyprland package's `share/hypr/stubs`. Two `.luarc.json` files reference that path:

- `lua/.luarc.json` (in-repo, committed) — picked up when editing the lua tree directly from `~/killuanix`.
- `~/.config/hypr/.luarc.json` (HM-written) — picked up when editing via the symlinked entry point.

`lua-language-server` walks upward from the buffer file looking for `.luarc.json`, so both editors agree on the library path.

In Neovim/Zed, opening `lua/keybinds.lua` and typing `hl.dsp.` should now offer `focus`, `window.kill`, `workspace.toggle_special`, `exec_cmd`, etc.

## Bind flag mapping (old → new)

Old keybinds.nix had one list per hyprlang variant. In `lua/keybinds.lua` every entry is a single record with optional booleans; `M.register()` translates them to `hl.bind` options.

| Old hyprlang | New record fields | `hl.bind` flags |
|---|---|---|
| `bind`   | (none) | `{}` |
| `bindd`  | `desc = "…"` | `{ description }` |
| `bindl`  | `locked = true` | `{ locked }` |
| `bindel` | `repeating = true` | `{ repeating }` |
| `bindle` | `repeating = true, locked = true` | `{ repeating, locked }` |
| `bindld` | `locked = true, desc = "…"` | `{ locked, description }` |
| `bindm`  | `drag = true` (mouse drag) | `{ drag }` |
| `binde`  | `repeating = true` | `{ repeating }` |

## Leader submap

Adding a new submap: extend the `submaps` list in `lua/leader.lua` (set `name`, `trigger`, `slots`) and add a matching entry to `leaderHudMetadata` in `default.nix` (icon + display name + activator key + `slots = [{key,label}…]` for the cheatsheet overlay). Slot keys must stay in sync between the lua list (where they're bound) and the nix metadata (where they're displayed).

The HUD plugin reads:
- `~/.cache/leader-hud/state` — written by `lua/leader.lua` on submap enter (`echo NAME > state`) / exit (`echo '' > state`).
- `~/.config/leader-hud/submaps.json` — written by `default.nix` from `leaderHudMetadata`.

## Per-host overrides

`lua/hyprland.lua` puts both the shared `lua/` dir **and** `~/.config/hypr/` on `package.path`, then `try_require()`s two optional per-host files (no-ops if absent):

- `try_require("device-monitors")` — per-host monitor layout (see Monitors below). **chrollo** ships one (`chrollo/home-manager/device-monitors.lua`, symlinked to `~/.config/hypr/device-monitors.lua` from `chrollo/home-manager/home.nix`).
- `try_require("device-gestures")` — per-host touchpad gestures. **chrollo only** (`chrollo/home-manager/device-gestures.lua`, symlinked from `chrollo/home-manager/home.nix`); killua handheld has none.
- `try_require("device-keybinds")` — per-host keybind extras. **chrollo** ships one (`chrollo/home-manager/device-keybinds.lua`, symlinked from `chrollo/home-manager/home.nix`): a `long_press` bind on `XF86PowerOff` that opens the DMS power menu (`dms ipc call powermenu open`). Short power-button taps are handled by logind (`HandlePowerKey=suspend` + DMS `lockBeforeSuspend`, `chrollo/power.nix`); the long press is left `ignore` in logind so this Hyprland bind owns it. killua/archnix ship none.

## What's left in pure nix

- **Monitors** — native Hyprland `hl.monitor{}` rules per host, loaded via `try_require("device-monitors")`. **Do not** add `services.kanshi` back — running kanshi on top of Hyprland double-reconfigures outputs on hotplug and crashes every Wayland client with `wl_display: invalid object` on undock (the bug this replaced). Both hosts' kanshi.nix are deleted.
  - **chrollo** — `chrollo/home-manager/device-monitors.lua`. `eDP-1` is the anchor at `auto`; externals (`HDMI-A-1`/`DP-1`) use `auto-left`, so Hyprland reflows on plug/unplug — laptop + external side by side, single owner, no race.
  - **killua** (handheld) — `killua/device-monitors.lua`. Same static `auto`/`auto-left` rules as chrollo: the handheld panel stays on when docked and an external **extends** the desktop (departs from the old kanshi docked profiles, which disabled eDP). No black-screen risk.
  - Both call `require("ws-external").setup("eDP-1")` so **workspaces 1-6 move onto a connected external** (port-agnostic; see `lua/ws-external.lua` and the Files table). On unplug Hyprland returns those workspaces to `eDP-1` natively.
  - **Live layout GUI (`nwg-displays`)** — launched from the app menu as **"Displays Settings"** (no keybind). The upstream `.desktop` is overridden in `modules/common/programs/desktop/desktopfile.nix` (same id shadows the package entry via `~/.local/share/applications` precedence) so its persist output goes to `$XDG_RUNTIME_DIR/nwg-{monitors,workspaces}.conf` **throwaways** (`-m`/`-w`), never clobbering `device-monitors.lua` or the read-only pinned `hyprland.conf`. It applies live via `hyprctl keyword monitor` regardless of the lua config — that's the on-the-fly repositioning. Do not point it at `~/.config/hypr/`: that reintroduces a two-owner config race and its static `workspace=monitor` lines break the port-agnostic `ws-external` logic. Live tweaks are ephemeral; a hyprland reload snaps back to the lua layout. Persist a position by copying the values into the host's `device-monitors.lua`. Pkg is in `packages.nix` `desktopPackages`.
- **System-level Hyprland** — `programs.hyprland.enable = true` (UWSM, portals, session target) lives in the NixOS host configs, not here.
- **Workspaces** — `~/.config/hypr/workspaces.conf` is empty on every host; if you need workspace pinning add a `hl.workspace_rule` to `lua/rules.lua`.
