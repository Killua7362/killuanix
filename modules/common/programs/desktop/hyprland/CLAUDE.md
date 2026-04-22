# Hyprland Module

Hyprland window manager configuration, split into focused submodules. The primary modifier key is `SUPER`. Package is sourced in Configuration.nix for NixOS and home.nix for ArchLinux + Home Manager setup with xwayland enabled and systemd integration disabled in favor of UWSM.

## Files

| File | Purpose |
|---|---|
| `default.nix` | Entry point. Enables Hyprland, sources external `monitors.conf` and `workspaces.conf`, and imports all submodules. |
| `env.nix` | Environment variables: fcitx input method, Wayland/XDG session identifiers, Qt theming (gtk3), accessibility flags, terminal (`ghostty`). |
| `general.nix` | General settings: scrolling layout, border colors, gaps (5 in / 10 out), tearing allowed, snap enabled. |
| `layout.nix` | Layout engines: dwindle (preserve split, pseudotile), scrolling (column widths `1.0, 0.5`), master, decoration (rounding 8, blur, shadows), cursor, and bind scroll settings. |
| `keybinds.nix` | All keybindings across `bind`, `bindd`, `bindle`, `bindel`, `bindl`, `bindld`, `bindm`, and `binde` categories. Covers window management, workspace switching (Super+1-0), focus/move, media keys, volume, brightness, screenshots (Print -> slurp + grim + satty), terminal launch (Super+Return -> ghostty), and quickshell integration. |
| `windowrules.nix` | Window rules (float/pin/size for blueman, PiP, file dialogs, pavucontrol, etc.), workspace rules, and extensive layer rules for quickshell namespaces, vicinae, and notification blur. |
| `execs.nix` | `exec-once` programs launched via UWSM: dms, hyprpolkitagent, wl-paste + cliphist, nm-applet, blueman-applet, sunshine. Also sets dbus activation environment. |
| `input.nix` | Currently empty (placeholder). |
| `gestures.nix` | Touchpad gestures: workspace swipe config and multi-finger gestures (3-finger swipe move, 4-finger horizontal workspace switch, 4-finger pinch float, 4-finger up/down for quickshell overview). |
| `misc.nix` | Miscellaneous: animations enabled but all durations set to 0, VFR/VRR enabled, DPMS on mouse/key, swallow regex (disabled via `enable_swallow = false`), session lock restore + xray, background color, Hyprland logo/splash disabled, `force_default_wallpaper = -1`, `focus_on_activate`, scroller plugin `column_widths = "onehalf one"`, xwayland forced zero scaling. |
| `hypridle.nix` | Idle daemon: screen off after 5400s (90 min), DPMS restore on resume. Lock command uses `hyprlock` with duplicate prevention. |
| `hyprlock.nix` | Lock screen: blurred background image, centered clock and date labels, input field at bottom. Font: Rubik / Rubik Extrabold. |
| `dms.nix` | Enables dank-material-shell and its `vmManager` plugin (sourced from `vms/vm-manager-plugin`). |

## Notable Details

- **Layout engine**: `scrolling` (set in `general.nix`), with dwindle and master available as fallbacks in `layout.nix`.
- **Key modifier**: `$mod = SUPER`.
- **Terminal**: `Super+Return` opens ghostty.
- **Lock**: `Super+L` and `Super+Alt+L` trigger lock via dms.
- **Screenshots**: `Print` key launches slurp region select piped through grim into satty.
- **Media controls**: hardware keys and `Super+Shift` combos for playerctl play/pause/next/prev.
- **Quickshell integration**: multiple `global` dispatches for sidebar, overview, emoji picker, cheatsheet, media controls, session menu, bar, and wallpaper selector.
- **Monitor/workspace config**: sourced from external `~/.config/hypr/monitors.conf` and `workspaces.conf` (not managed here).
