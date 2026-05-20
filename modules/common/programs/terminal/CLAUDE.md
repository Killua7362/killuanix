# Terminal Module

Home Manager configuration for two terminal emulators (ghostty, kitty) and the tmux terminal multiplexer, shared across all platforms. Ghostty is the primary terminal under Hyprland — `Super+Return` launches it (see `../desktop/hyprland/keybinds.nix`) and the Hyprland session sets `TERMINAL=ghostty` (see `../desktop/hyprland/env.nix`). Kitty remains available for ad-hoc use but is no longer the default wrapper.

## Files

| File | Description |
|---|---|
| `default.nix` | Aggregator module; imports `ghostty.nix`, `kitty.nix`, and `tmux.nix`. |
| `ghostty.nix` | Ghostty terminal emulator configuration (primary under Hyprland). |
| `kitty.nix` | Kitty terminal emulator configuration. |
| `tmux.nix` | Tmux terminal multiplexer configuration. |
| `zellij.nix` | Zellij configuration (disabled — import is commented in `default.nix`; file retained for revert). |

## Ghostty

- **Enabled** on Linux only (`lib.mkDefault pkgs.stdenv.isLinux`).
- **Font**: JetBrainsMono Nerd Font, size 12.
- **Window**: No decoration, 12px padding on both axes, full opacity (`background-opacity = 1.0`).
- **Cursor**: Block style with blink.
- **Shell**: zsh (via `shell-integration = "zsh"` and `command = "zsh"`).
- **Clipboard**: `copy-on-select = clipboard`, explicit `ctrl+shift+c`/`ctrl+shift+v` bindings.
- **Scrollback**: 1000000 lines (raised from 3000 — long claude-code conversations were rolling out of the buffer mid-scroll).
- **Theme**: All colors (`background`, `foreground`, `cursor-color`, `cursor-text`, `selection-background`/`foreground`, and the full ANSI 16 palette `color0`–`color15`) are pulled from `config.theme.palette` — see `../theming/palette.nix` for the shared palette definition.
- **Keybindings**: Font size controls (`ctrl+plus`/`ctrl+minus`/`ctrl+0`), new window (`ctrl+shift+n`).
- **Multiplexer pass-through**: Explicitly unbinds `ctrl+a`, `ctrl+g`, `ctrl+h`, `ctrl+n`, `ctrl+o`, `ctrl+p`, `ctrl+q`, `ctrl+s`, `ctrl+t`, `ctrl+w`, `ctrl+tab`, `ctrl+shift+tab` so Ghostty never swallows them. Originally for zellij; still required so `Ctrl-a` (tmux prefix) and the rest reach tmux cleanly.

## Kitty

- **Enabled** on Linux only (`lib.mkDefault (pkgs.stdenv.isLinux)`).
- **Font**: JetBrainsMono Nerd Font, size 12.
- **Theme**: Custom dark color scheme defined inline via `extraConfig`. Background `#131313`, foreground `#e2e2e2`, blue accent `#89ceff`.
- **Shell**: zsh (set in `extraConfig`).
- **Window**: No decorations, full opacity, 32px background blur, 12px padding.
- **Tab bar**: Powerline style, left-aligned.
- **Keybindings**: Font size controls (`ctrl+plus`/`ctrl+minus`/`ctrl+0`), new window (`ctrl+shift+n`). Several default bindings are explicitly disabled with `no_op` (`ctrl+t`, `ctrl+n`, `ctrl+tab`, `ctrl+shift+tab`, `ctrl+w`) to avoid conflicts with the multiplexer.

## Tmux

HM `programs.tmux` with `extraConfig`. Single source of config; no `~/.tmux.conf` override.

- **Prefix**: `C-a` (replaces default `C-b`). Double-tap (`C-a C-a`) sends literal `C-a` for nested sessions / readline.
- **Mode**: vi (`keyMode = "vi"`).
- **Mouse**: on.
- **Base index**: 1 (windows + panes) — numeric jumps line up with the `1..9` keys.
- **Escape time**: 0 (no lag on `<esc>` in nvim).
- **History limit**: 1,000,000 lines per pane (matches the ghostty scrollback bump).
- **Terminal**: `tmux-256color` + `terminal-overrides ",xterm-256color:RGB,ghostty:RGB"` so RGB true-color propagates inside tmux.
- **Default shell**: zsh.
- **Plugins** (nix-managed via `pkgs.tmuxPlugins`): `sensible`, `yank`, `vim-tmux-navigator`. No session-persistence plugins (resurrect/continuum) by design — sessions are stateless.

### Keybinds (mirror zellij muscle memory)

- **Splits**: `prefix h` vertical (new pane right), `prefix r` horizontal (new pane down). `prefix |` / `prefix -` are alternates. All open at `#{pane_current_path}`.
- **Pane nav (prefix)**: vim `h/j/k/l` (h via vim-tmux-navigator forwarding) and Colemak `n/e/i/o`.
- **Pane nav (no prefix)**: `Alt-Left/Down/Up/Right` and `Alt-n/e/i/o`. The Colemak left/right edges fall through to `previous-window` / `next-window` (mirrors zellij `MoveFocusOrTab`). `vim-tmux-navigator` handles `Alt-h/j/k/l` so the same chord transparently moves between nvim splits and tmux panes (requires the counterpart plugin in nvim; currently the DotFiles submodule still uses `swaits/zellij-nav.nvim` — known follow-up).
- **Windows** (zellij "tabs"): `Alt-h` new window, `Alt-w` close pane, `Alt-[` / `Alt-]` cycle, `Alt-Shift-i` / `Alt-Shift-o` move window left/right, `Ctrl-Tab` / `Ctrl-Shift-Tab` cycle, `prefix 1..9` jump, `prefix c` new window.
- **Resize**: `Alt-+` / `Alt--` / `Alt-=` no prefix. `prefix H/J/K/L` repeatable (5/3/3/5).
- **Zoom**: `prefix f` or `Alt-f` (`resize-pane -Z`).
- **Kill**: `prefix x` pane, `prefix X` window.
- **Floating popup shell**: `prefix w` or `Alt-t` — `display-popup -E -w 80% -h 80%` at `#{pane_current_path}`.
- **Project picker**: `prefix p` or `Alt-p` — runs `~/killuanix/scripts/zj-proj` in `display-popup`. The script itself currently runs `zellij action new-tab` on select (no-ops outside zellij); cancel closes the popup cleanly. Follow-up: branch on `$TMUX` and call `tmux new-window -c "$sel"`.
- **Session picker**: `prefix s` or `Alt-s` → `choose-tree -Zs`. Detach via `prefix d`.
- **Copy mode**: `prefix [` or `Ctrl-s`. `v` begin-selection, `y`/`Y` copy-pipe-and-cancel to `wl-copy`. Mouse drag-end pipes to `wl-copy` too.
- **Edit scrollback** (zellij `Ctrl-a v`): `prefix v` captures `-S -1000000` to a tempfile, opens it in `nvim` via `tmux new-window`.
- **Reload**: `prefix R` → `source-file ~/.config/tmux/tmux.conf`.

### Status bar

Palette-driven via `config.theme.palette` (same source as kitty/ghostty/qutebrowser). Background uses `zellij_bg` (`#1c1c1c`) so the bar stays a hair lighter than the ghostty body. Session-name pill on the left in `color4` (blue accent) over `bg`; window list in `fg`/`zellij_bg`, current window inverted to `bg`/`color4`. Right side shows hostname (`color9`) and `%Y-%m-%d %H:%M`. Pane borders inactive `color0`, active `color4`. Message + mode lines use `color4` over `bg`.

### Out-of-scope follow-ups

- `DotFiles/nvim/lua/plugins/zellij-nav.lua` → swap to `christoomey/vim-tmux-navigator` so the Alt-nav chords cross nvim splits.
- `DotFiles/nvim/lua/plugins/sidekick.lua:16` `backend = "zellij"` → `"tmux"`.
- `scripts/zj-proj` line 22 calls `zellij action new-tab`; adapt to detect `$TMUX` and call `tmux new-window -c "$sel"` instead.
- `scripts/tmux-sessionizer.sh` is referenced by the `ts` shell alias but doesn't exist yet.

## Zellij (disabled)

`zellij.nix` is no longer imported in `default.nix`; the file is kept on disk so the previous configuration can be restored by uncommenting one line. Related stragglers left in place: `palette.zellij_bg` (reused as the tmux status bg), the `zboot()` zsh function (now dormant), and `scripts/zj-proj` (currently wired into tmux via `display-popup` but still uses zellij commands internally).

## Integration

`default.nix` is imported by the parent `modules/common/programs/` module tree, which feeds into `modules/cross-platform/default.nix` for all platforms.
