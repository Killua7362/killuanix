# Terminal Module

Home Manager configuration for two terminal emulators (ghostty, kitty) and the zellij terminal multiplexer, shared across all platforms. Ghostty is the primary terminal under Hyprland — `Super+Return` launches it (see `../desktop/hyprland/keybinds.nix`) and the Hyprland session sets `TERMINAL=ghostty` (see `../desktop/hyprland/env.nix`). Kitty remains available for ad-hoc use but is no longer the default wrapper.

## Files

| File | Description |
|---|---|
| `default.nix` | Aggregator module; imports `ghostty.nix`, `kitty.nix`, and `zellij.nix`. |
| `ghostty.nix` | Ghostty terminal emulator configuration (primary under Hyprland). |
| `kitty.nix` | Kitty terminal emulator configuration. |
| `zellij.nix` | Zellij terminal multiplexer configuration. |

## Ghostty

- **Enabled** on Linux only (`lib.mkDefault pkgs.stdenv.isLinux`).
- **Font**: JetBrainsMono Nerd Font, size 12.
- **Window**: No decoration, 12px padding on both axes, full opacity (`background-opacity = 1.0`).
- **Cursor**: Block style with blink.
- **Shell**: zsh (via `shell-integration = "zsh"` and `command = "zsh"`).
- **Clipboard**: `copy-on-select = clipboard`, explicit `ctrl+shift+c`/`ctrl+shift+v` bindings.
- **Scrollback**: 3000 lines.
- **Theme**: All colors (`background`, `foreground`, `cursor-color`, `cursor-text`, `selection-background`/`foreground`, and the full ANSI 16 palette `color0`–`color15`) are pulled from `config.theme.palette` — see `../theming/palette.nix` for the shared palette definition.
- **Keybindings**: Font size controls (`ctrl+plus`/`ctrl+minus`/`ctrl+0`), new window (`ctrl+shift+n`).
- **Zellij pass-through**: Explicitly unbinds `ctrl+a`, `ctrl+g`, `ctrl+h`, `ctrl+n`, `ctrl+o`, `ctrl+p`, `ctrl+q`, `ctrl+s`, `ctrl+t`, `ctrl+w`, `ctrl+tab`, `ctrl+shift+tab` so Ghostty never swallows them. This is why `Ctrl-a`, `Ctrl-p`, etc. reach zellij cleanly for mode switching.

## Kitty

- **Enabled** on Linux only (`lib.mkDefault (pkgs.stdenv.isLinux)`).
- **Font**: JetBrainsMono Nerd Font, size 12.
- **Theme**: Custom dark color scheme defined inline via `extraConfig`. Background `#131313`, foreground `#e2e2e2`, blue accent `#89ceff`.
- **Shell**: zsh (set in `extraConfig`).
- **Window**: No decorations, full opacity, 32px background blur, 12px padding.
- **Tab bar**: Powerline style, left-aligned.
- **Keybindings**: Font size controls (`ctrl+plus`/`ctrl+minus`/`ctrl+0`), new window (`ctrl+shift+n`). Several default bindings are explicitly disabled with `no_op` (`ctrl+t`, `ctrl+n`, `ctrl+tab`, `ctrl+shift+tab`, `ctrl+w`) to avoid conflicts with zellij.

## Zellij

- **Enabled** unconditionally on all platforms.
- **Default shell**: zsh.
- **Theme**: `onedark`.
- **Copy command**: `wl-copy` (Wayland).
- **Keybinds**: Uses `clear-defaults=true` with a fully custom keybind set. Navigation uses both arrow keys and Colemak-style (`n`/`e`/`i`/`o`) plus Vim-style (`h`/`j`/`k`/`l`) bindings.
  - `Ctrl a` enters tmux-compatibility mode.
  - `Ctrl g` toggles locked mode.
  - `Ctrl p` / `Ctrl t` / `Ctrl s` / `Ctrl o` / `Ctrl h` switch to pane, tab, scroll, session, and move modes respectively.
  - `Ctrl n` enters resize mode.
  - `Ctrl q` quits.
  - `Alt` shortcuts provide quick access without mode switching: `Alt h` new pane, `Alt t` toggle floating panes, `Alt f` fullscreen, `Alt w` close focused pane, `Alt +/-` resize.
- **Plugins**: Loads built-in zellij plugins plus `zellij-autolock` (auto-locks on nvim, vim, git, fzf, zoxide, atuin, git-forgit).
- **Environment**: Sets `WAYLAND_DISPLAY=wayland-1`.

## Integration

`default.nix` is imported by the parent `modules/common/programs/` module tree, which feeds into `modules/cross-platform/default.nix` for all platforms.
