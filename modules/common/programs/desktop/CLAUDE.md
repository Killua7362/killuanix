# Desktop Module

Desktop environment configuration shared across Linux platforms. Covers the Hyprland window manager, screenshot annotation, and custom XDG desktop entries.

## Files

| File | Purpose |
|---|---|
| `default.nix` | Entry point. Imports `hyprland/`, `satty.nix`, and `desktopfile.nix`. |
| `satty.nix` | Configures the Satty screenshot annotation tool. Output saved to `~/Pictures/Screenshots/` with timestamped filenames. Saves to file on Enter. |
| `desktopfile.nix` | Custom XDG desktop entries. `google-chrome-sock` launches Chrome through a SOCKS5 proxy (`127.0.0.1:1080`) with a separate user data dir (`~/.config/teams-vpn-chrome`). `nwg-displays` **overrides** the upstream "Displays Settings" launcher so its persist output is redirected to `$XDG_RUNTIME_DIR` throwaways (`-m`/`-w`) — keeps the app-menu display tool from clobbering the declarative lua monitor layout; see `hyprland/CLAUDE.md` Monitors. |

## Submodules

- **`hyprland/`** -- Full Hyprland window manager configuration split into keybinds, layout, window rules, environment, gestures, idle/lock, and more. See [`hyprland/CLAUDE.md`](hyprland/CLAUDE.md) for details.
- **`qml/`** -- In-repo QML workspace: custom DankMaterialShell plugins + per-folder neovim LSP setup. Plugins wired into DMS via `programs.dank-material-shell.plugins.<id>.src` in `hyprland/dms/default.nix`. Currently: `leader-hud` (bar pill showing active Hyprland leader submap; reads `~/.cache/leader-hud/state` + `~/.config/leader-hud/slots.json` written by `hyprland/leader.nix`). The folder also ships a HM activation builder that synthesizes a `qs.*` qmldir tree under `~/.cache/qml-workspace/` so `qmlls6` can autocomplete DMS internals; see [`qml/CLAUDE.md`](qml/CLAUDE.md).

## Integration

`default.nix` is imported by the top-level `modules/common/programs/programs.nix`, which aggregates all program modules for consumption by `modules/cross-platform/default.nix`.
