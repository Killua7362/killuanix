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
| `lua/hyprland.lua` | Entry point loaded by Hyprland. Extends `package.path` then `require()`s the sibling modules in order (env → general → misc → layout → input → gestures → rules → execs → leader → keybinds.register). |
| `lua/.luarc.json` | LSP config so opening the lua tree directly in Neovim/Zed picks up the stubs. The same JSON is also dropped at `~/.config/hypr/.luarc.json` from nix for buffers opened via the symlink. |
| `lua/env.lua` | `hl.config{ env = { … } }`. Fcitx + Wayland/XDG session ids + Qt theming + accessibility flags. |
| `lua/general.lua` | `hl.config{ general = { … } }`. Scrolling layout, border colors, gaps, snap, tearing. |
| `lua/misc.lua` | `hl.config{ misc, xwayland, plugin, animations }` + `hl.animation` calls to disable every leaf. |
| `lua/layout.lua` | `hl.config{ dwindle, decoration, binds, cursor, master, scrolling }`. |
| `lua/input.lua` | Empty placeholder. Add device-specific tweaks here. |
| `lua/gestures.lua` | Touchpad gestures + multi-finger swipe/pinch dispatchers. |
| `lua/rules.lua` | `hl.window_rule` / `hl.layer_rule` / `hl.workspace_rule` calls. PiP, file dialogs, blueman, Zotero, Kodi, JetBrains Xwayland popups, quickshell namespace blur/animation. |
| `lua/keybinds.lua` | Flat data table `M.binds` of every keybind + `M.register()` walker. Action helpers (`A.focus_dir`, `A.swap_dir`, `A.move_ws`, `A.layout`, …) build dispatchers lazily so the module loads without `hl` defined. Flag mapping in the header comment. |
| `lua/leader.lua` | `hl.define_submap("leader", …)` + the trigger bind. Writes `~/.cache/leader-hud/state` on enter/exit for the LeaderHud DMS bar plugin. Add more submaps by extending the `submaps` table. |
| `lua/execs.lua` | `hl.on("hyprland.start", …)` with `uwsm app --` wrappers (dms, hyprpolkitagent, nm-applet, blueman-applet, sunshine). |
| `clipboard.nix` | Systemd user services `cliphist-text` / `cliphist-image` running `wl-paste --watch`. `Restart=always` + `KillMode=mixed` so children are reaped on restart. |
| `hypridle.nix` | Idle daemon: screen off after 5400s; `hyprctl dispatch dpms on/off` on transitions. |
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

## Per-host overrides (not wired yet)

`lua/hyprland.lua` already calls `try_require("device-keybinds")` so per-host extras can be added later by dropping a `device-keybinds.lua` somewhere on `package.path` (currently only the `lua/` dir is on the path; extend `LUA_DIR` to add a host directory).

## What's left in pure nix

- **Monitors** — `services.kanshi` per host (`killua/kanshi.nix`, `chrollo/home-manager/kanshi.nix`).
- **System-level Hyprland** — `programs.hyprland.enable = true` (UWSM, portals, session target) lives in the NixOS host configs, not here.
- **Workspaces** — `~/.config/hypr/workspaces.conf` is empty on every host; if you need workspace pinning add a `hl.workspace_rule` to `lua/rules.lua`.
