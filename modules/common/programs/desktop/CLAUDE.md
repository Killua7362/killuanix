# Desktop Module

Desktop environment configuration shared across Linux platforms. Covers the Hyprland window manager, screenshot annotation, and custom XDG desktop entries.

## Files

| File | Purpose |
|---|---|
| `default.nix` | Entry point. Imports `hyprland/`, `satty.nix`, and `desktopfile.nix`. |
| `satty.nix` | Configures the Satty screenshot annotation tool. Output saved to `~/Pictures/Screenshots/` with timestamped filenames. Saves to file on Enter. |
| `desktopfile.nix` | Defines a custom XDG desktop entry `google-chrome-sock` that launches Chrome through a SOCKS5 proxy (`127.0.0.1:1080`) with a separate user data dir (`~/.config/teams-vpn-chrome`). |

## Submodules

- **`hyprland/`** -- Full Hyprland window manager configuration split into keybinds, layout, window rules, environment, gestures, idle/lock, and more. See [`hyprland/CLAUDE.md`](hyprland/CLAUDE.md) for details.

## Integration

`default.nix` is imported by the top-level `modules/common/programs/programs.nix`, which aggregates all program modules for consumption by `modules/cross-platform/default.nix`.
