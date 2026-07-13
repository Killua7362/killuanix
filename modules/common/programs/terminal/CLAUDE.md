# Terminal Module

Home Manager configuration for terminal emulators (wezterm, ghostty, kitty), shared across all platforms. **WezTerm is the primary terminal + multiplexer under Hyprland** — `Super+Return` launches `wezterm connect unix` (see `../desktop/hyprland/lua/keybinds.lua`) and the Hyprland session sets `TERMINAL=wezterm` (see `../desktop/hyprland/lua/env.lua`). It replaces the old tmux + zellij stack: WezTerm's native mux only works when WezTerm is the terminal, so both the emulator and the multiplexer are now the same process. Ghostty and kitty are kept installed as fallback emulators. `tmux.nix` / `zellij.nix` are retained on disk (imports commented) for revert.

## Files

| File | Description |
|---|---|
| `default.nix` | Aggregator module; imports `ghostty.nix`, `kitty.nix`, and `wezterm.nix`. `tmux.nix` / `zellij.nix` imports are commented. |
| `wezterm.nix` | WezTerm terminal + native multiplexer (primary under Hyprland). Gated to chrollo/killua via the `hostName` specialArg. |
| `ghostty.nix` | Ghostty terminal emulator configuration (fallback). |
| `kitty.nix` | Kitty terminal emulator configuration (fallback). |
| `tmux.nix` | Tmux config (disabled — import commented in `default.nix`; retained for revert). |
| `zellij.nix` | Zellij config (disabled — import commented in `default.nix`; retained for revert). |

## Ghostty

- **Enabled** on Linux only (`lib.mkDefault pkgs.stdenv.isLinux`).
- **Font**: JetBrainsMono Nerd Font, size 12.
- **Window**: No decoration, 12px padding on both axes, full opacity (`background-opacity = 1.0`).
- **Cursor**: Bar style with blink (was block — bar reads thinner in tmux copy-mode, which uses the terminal's real cursor since tmux 3.6 has no per-copy-mode cursor option).
- **Shell**: zsh (via `shell-integration = "zsh"` and `command = "zsh"`).
- **Clipboard**: `copy-on-select = clipboard`, explicit `ctrl+shift+c`/`ctrl+shift+v` bindings.
- **Scrollback**: 1000000 lines (raised from 3000 — long claude-code conversations were rolling out of the buffer mid-scroll).
- **Theme**: All colors (`background`, `foreground`, `cursor-color`, `cursor-text`, `selection-background`/`foreground`, and the full ANSI 16 palette `color0`–`color15`) are pulled from `config.theme.palette` — see `../theming/palette.nix` for the shared palette definition.
- **Keybindings**: Font size controls (`ctrl+plus`/`ctrl+minus`/`ctrl+0`), new window (`ctrl+shift+n`).
- **Ctrl-Backspace**: `ctrl+backspace=text:\x17` overrides Ghostty's default `^H` so the chord sends `^W` instead — zsh/fish/readline then perform backward-kill-word.
- **Multiplexer pass-through**: Explicitly unbinds `ctrl+a`, `ctrl+g`, `ctrl+h`, `ctrl+n`, `ctrl+o`, `ctrl+p`, `ctrl+q`, `ctrl+s`, `ctrl+t`, `ctrl+w`, `ctrl+tab`, `ctrl+shift+tab` so Ghostty never swallows them. Originally for zellij; still required so `Ctrl-a` (tmux prefix) and the rest reach tmux cleanly.

## Kitty

- **Enabled** on Linux only (`lib.mkDefault (pkgs.stdenv.isLinux)`).
- **Font**: JetBrainsMono Nerd Font, size 12.
- **Theme**: Custom dark color scheme defined inline via `extraConfig`. Background `#131313`, foreground `#e2e2e2`, blue accent `#89ceff`.
- **Shell**: zsh (set in `extraConfig`).
- **Window**: No decorations, full opacity, 32px background blur, 12px padding.
- **Tab bar**: Powerline style, left-aligned.
- **Keybindings**: Font size controls (`ctrl+plus`/`ctrl+minus`/`ctrl+0`), new window (`ctrl+shift+n`). Several default bindings are explicitly disabled with `no_op` (`ctrl+t`, `ctrl+n`, `ctrl+tab`, `ctrl+shift+tab`, `ctrl+w`) to avoid conflicts with the multiplexer.

## WezTerm

HM `programs.wezterm` with `extraConfig` — a raw Lua string written verbatim to `~/.config/wezterm/wezterm.lua`. Palette values are interpolated from `config.theme.palette` (static, same source as kitty/ghostty). **Colemak neio = left/down/up/right** throughout.

- **Enabled** only on `chrollo` + `killua` (`pkgs.stdenv.isLinux && (hostName == "chrollo" || "killua")`). The `hostName` specialArg is passed only for those two NixOS hosts (flake.nix), so it is `null` on archnix/macnix and the module stays disabled there — archnix already symlinks `~/.config/wezterm` from DotFiles (would collide) and macnix uses the Homebrew wezterm.
- **Appearance**: JetBrainsMono Nerd Font 12, no window decorations, 12px padding, scrollback 1,000,000. Colors + `tab_bar` colors from the palette. **Fancy tab bar** at top (`use_fancy_tab_bar = true`), always shown, no new-tab button, `window_frame` = bold Nerd Font 11 on `zellij_bg`. A `format-tab-title` handler renders each tab as `<index>:<title>` (title = tab title, else foreground process basename, else pane title, truncated), active tab bold; active/inactive backgrounds come from `colors.tab_bar`.
- **Ctrl-Backspace**: sends `\x17` (`^W`) so zsh/readline does backward-kill-word — WezTerm otherwise emits bare `^H` (plain backspace). Mirrors the ghostty binding.
- **Persistence**: `unix_domains = { { name = "unix" } }`. `Super+Return` runs `wezterm connect unix`, so panes/tabs/workspaces survive closing the GUI window (disconnect-only — nothing is restored across reboot, same as base tmux/zellij; no resurrect plugin).
- **Leader**: `C-a` (tmux prefix parity), 1s timeout.

### Key scheme

Two entry styles, mirroring the combined tmux+zellij muscle memory:

- **Direct `Ctrl-<letter>` modal modes** (zellij-style): `Ctrl-p` pane, `Ctrl-t` tab, `Ctrl-n` resize, `Ctrl-h`/`Ctrl-m` move, `Ctrl-s` copy mode, `Ctrl-g` lock. Each modal table is entered with `prevent_fallback` so stray keys are swallowed (stay in mode); `Escape`/`Enter`/the same `Ctrl-<letter>` pops back.
- **`C-a` leader prefix binds** (tmux-style): `h` split right, `r` split down, `c` new tab, `x` close pane, `f` zoom, `d` detach (mux), `s`/`p` workspace launcher, `[` copy mode, `R` reload, `v` scrollback→nvim, `1..9` jump to tab.

Direct Alt actions (no mode): `Alt-neio` seamless nav (see below), `Alt-h` new tab, `Alt-f` zoom, `Alt-w` close pane, `Alt-s`/`Alt-p` workspace fuzzy launcher, `Alt-x` QuickSelect, `Alt-[`/`Alt-]` prev/next workspace, `Alt-Shift-i`/`Alt-Shift-o` move tab, `Ctrl-Tab`/`Ctrl-Shift-Tab` cycle tabs.

### Modal key-tables

- **`pane_mode` (`Ctrl-p`)**: `h`/`r` split right, `d` split down, `f` zoom, `x` close, `p` pane picker, `neio`/arrows move focus (stay).
- **`tab_mode` (`Ctrl-t`)**: `h` new tab, `x` close tab, `r` rename (PromptInputLine → `tab:set_title`), `b` break pane to new tab (`pane:move_to_new_tab()`), `neio`/arrows cycle, `1..9` jump, `Tab` last tab.
- **`resize_mode` (`Ctrl-n`)**: `neio`/`hjkl`/arrows `AdjustPaneSize` toward direction; `+`/`=`/`-`.
- **`move_mode` (`Ctrl-h`/`Ctrl-m`)**: `Tab` rotate clockwise, `p` counter-clockwise, `neio` open pane picker to swap (`SwapWithActiveKeepFocus`). **Limitation**: WezTerm has no directional pane-swap, so this approximates the tmux behavior.
- **`copy_mode` (`Ctrl-s` / leader `[`)**: starts from `wezterm.gui.default_key_tables().copy_mode`, then **prepends** neio movement, `v`/`V`/`Ctrl-v` cell/line/block select, `g`/`G` scrollback top/bottom, `y` → clipboard+primary then close, `q` close. Prepending makes these win over the stock `hjkl`/`v`/`y`.
- **`locked` (`Ctrl-g`)**: only `Ctrl-g`/`Escape` pop; entered with `prevent_fallback` so every other key passes to the program.

### Autolock passthrough

Only **`Ctrl-p`** (pane mode) and **`Ctrl-n`** (resize mode) are wrapped in a `guarded()` callback — matching the old zellij setup, whose binds for those two excluded `"locked"` while `Ctrl-t`/`Ctrl-s`/`Ctrl-h`/`Ctrl-m`/`Ctrl-a`/`Ctrl-Tab` stayed with the mux in every mode. So `Ctrl-t` (tab), `Ctrl-s` (copy), `Ctrl-h`/`Ctrl-m` (move) are plain binds that always grab regardless of focus. The guard: if the focused pane sets the `IS_NVIM` user-var **or** any process/`WEZTERM_PROG` matches a trigger, the chord is `SendKey`-forwarded to the program instead of switching modes.

Because `Super+Return` launches `wezterm connect unix`, panes live on the mux server and `get_foreground_process_name()` / `get_tty_name()` return **nil** — so process detection can't see anything, and the only signals that cross the mux are OSC 1337 user vars. Checked in order:

- **`IS_NVIM` user-var (nvim).** `modules/common/programs/editors/neovim/lua/config/autocmds.lua` emits `SetUserVar=IS_NVIM=true` on `VimEnter`/`VimResume`, `false` on `VimLeave`/`VimSuspend`. Makes Ctrl-n/p/t/etc reach nvim. (Minimal user-var emit, **not** smart-splits.nvim — seamless Alt-nav is still deferred.)
- **`WEZTERM_PROG` user-var (shell commands: fzf, forgit, lazygit, git, …).** `modules/common/programs/shells/zsh.nix` adds a zsh `preexec` that emits `SetUserVar=WEZTERM_PROG=<command word>` and a `precmd` that clears it. forgit aliases (e.g. `gcio`/`gcoi`) resolve to fzf, so the hook inspects the command's `type` output and marks anything referencing `forgit`/`fzf` as `"fzf"` — no need to enumerate aliases. `is_passthrough` matches `WEZTERM_PROG` against the trigger substrings.
- **tty process scan (fallback — non-mux panes only, e.g. a plain `wezterm` window).** When a tty is available, runs `${procps}/bin/ps -o comm= -t <tty>` via `wezterm.run_child_process` and matches trigger substrings `nvim vim view git fzf zoxide atuin lazygit zj-proj ghgrab` (loose `find`, so `.fzf-wrapped` / `git-forgit` still hit). Scans **all** tty processes, not just the pgrp leader.

`Ctrl-g` (lock) and `Ctrl-q` (quit) are never guarded.

### Nav

`Alt-neio` always `ActivatePaneDirection` between WezTerm panes (never forwarded into nvim — the stale `zellij-nav.nvim` binding would eat it). nvim split navigation stays on `Ctrl-w neio`. Seamless nvim-split↔pane crossing (smart-splits.nvim) is deferred; the `IS_NVIM` user-var is emitted by nvim (see Autolock) but currently only drives the modal-chord passthrough, not nav.

### Other behavior

- **QuickSelect** (`Alt-x`): replaces the zextract hint picker — built-in url/path/hash patterns plus `quick_select_patterns` extras (git-sha, ipv4).
- **Projects/sessions**: the floating `zj-proj` popup and scratch-shell popup were **dropped** (WezTerm has no floating panes). Projects/sessions use the native fuzzy workspace launcher (`ShowLauncherArgs FUZZY|WORKSPACES`) on `Alt-s`/`Alt-p` and leader `s`/`p`.
- **Scrollback→nvim** (leader `v`): dumps the pane's last 20k lines (`wezterm cli get-text --start-line -20000`) to `/tmp/wz-scroll.txt`, opens it in nvim in a new tab, removes the temp file on exit (may hold secrets).
- **synchronize-panes**: dropped (no native support).
- **Status bar**: `update-status` event — left = a **mode pill** (`window:active_key_table()` → PANE/TAB/RESIZE/MOVE/COPY/SEARCH in `color9`, LOCKED and a pending C-a PREFIX in `color1`; hidden in normal mode) followed by the active workspace name (`color4` on `bg`, bold); right = hostname (`color9`) + `| %Y-%m-%d %H:%M` (`fg`). Tab bar top, palette-colored.

## Tmux (disabled)

Import commented in `default.nix`; file retained for revert. HM `programs.tmux` with `extraConfig`. Single source of config; no `~/.tmux.conf` override.

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
- **Windows** (zellij "tabs"): `Alt-h` new window, `Alt-w` close pane, `Alt-Shift-i` / `Alt-Shift-o` move window left/right, `Ctrl-Tab` / `Ctrl-Shift-Tab` cycle, `prefix 1..9` jump, `prefix c` new window.
- **Layouts**: `Alt-[` / `Alt-]` previous / next layout (zellij `PreviousSwapLayout` / `NextSwapLayout`).
- **Resize**: `Alt-+` / `Alt--` / `Alt-=` no prefix. `prefix H/J/K/L` repeatable (5/3/3/5).
- **Zoom**: `prefix f` or `Alt-f` (`resize-pane -Z`).
- **Kill**: `prefix x` pane, `prefix X` window. `Ctrl-q` confirms then `kill-server` (zellij Quit).
- **Lock** (zellij `Ctrl-g`): `Ctrl-q`... no — `Ctrl-g` enters an empty `locked` key-table that swallows input until `Ctrl-g` or `Escape`.
- **Floating popup shell**: `prefix w` or `Alt-t` — `display-popup -E -w 80% -h 80%` at `#{pane_current_path}`.
- **Project picker**: `prefix p` or `Alt-p` — runs `~/killuanix/DotFiles/scripts/personal/zj-proj` in `display-popup`. The script itself currently runs `zellij action new-tab` on select (no-ops outside zellij); cancel closes the popup cleanly. Follow-up: branch on `$TMUX` and call `tmux new-window -c "$sel"`.
- **Session picker**: `prefix s` or `Alt-s` → `choose-tree -Zs`. Detach via `prefix d`.
- **Copy mode**: `prefix [` or `Ctrl-s` (zellij scroll mode). `v` begin-selection, `y`/`Y` copy-pipe-and-cancel to `wl-copy`. `u` half-page-up, `s` search-forward prompt, `q` / `Ctrl-s` cancel. Mouse drag-end pipes to `wl-copy` too.
- **Edit scrollback** (zellij `Ctrl-a v`): `prefix v` captures `-S -1000000` to a tempfile, opens it in `nvim` via `tmux new-window`.
- **Reload**: `prefix R` → `source-file ~/.config/tmux/tmux.conf`.

### Mode key-tables (zellij Ctrl+letter modes)

Ports zellij's modal navigation onto tmux key-tables. Root-level `Ctrl-<letter>` enters the table; navigation keys re-enter the same table (chain-friendly); mutation keys + `Escape` + `Enter` + the same `Ctrl-<letter>` return to root.

- **`Ctrl-p` — pane mode**: `h` new pane right, `d` split down, `r` split right, `f` zoom, `w` floating popup, `c` rename pane, `x` close pane, `z` toggle pane border status, `p` cycle pane focus, arrows + `h/j/k/l` + `n/e/i/o` move focus.
- **`Ctrl-t` — tab/window mode**: `h` new window, `x` close window, `r` rename, `b` break pane out, `[` break-pane and swap left, `]` break-pane and swap right, `Tab` last-window, `s` toggle synchronize-panes, `1..9` jump, arrows + `n/p/i/k` previous-window + `e/j/o/l` next-window.
- **`Ctrl-s` — scroll mode**: drops into tmux copy-mode (vi). Use `Ctrl-s` again or `q` to cancel.
- **`Ctrl-n` — resize mode**: arrows + lowercase vim/colemak increase pane toward direction; uppercase decrease (zellij convention). `+` / `=` increase up, `-` decrease.
- **`Ctrl-h` / `Ctrl-m` — move mode**: swap panes. `Tab` rotate down, `p` rotate up, arrows + `h/j/k/l` + `n/e/i/o` swap with neighbor in that direction.

**Autolock passthrough**: each `Ctrl-<letter>` mode-entry above is wrapped in an `if-shell` guard (`$is_autolocked`) that scans the focused pane's process via `ps -o state=,comm= -t '#{pane_tty}'`. When the foreground program matches `nvim|vim|view|git|fzf|zoxide|atuin|git-forgit|lazygit|zj-proj|ghgrab`, the chord is forwarded to the program via `send-keys` instead of switching tmux's key-table — the zellij-autolock equivalent. Claude is intentionally absent from the trigger list (see `Notes/claude/memory/project_zellij_autolock_claude.md`: user prefers driving multiplexer chords while a claude pane has focus). `Ctrl-g` (lock) and `Ctrl-q` (quit) are NOT wrapped — they always fire.

**Ctrl-Tab / Ctrl-Shift-Tab**: ghostty rebinds these to emit `\e.` / `\e,` (Alt-./Alt-,) — tmux's existing `bind -n M-.` / `M-,` then cycle windows. The CSI u path (`\e[9;5u`/`\e[9;6u`) was tried but tmux 3.6a normalizes Ctrl on Tab (Tab=^I collision) and forwards legacy `\e[Z` to the pane without matching any C-Tab/C-S-Tab/user-key bind.

### Status bar

Palette-driven via `config.theme.palette` (same source as kitty/ghostty/qutebrowser). Background uses `zellij_bg` (`#1c1c1c`) so the bar stays a hair lighter than the ghostty body. Session-name pill on the left in `color4` (blue accent) over `bg`; window list in `fg`/`zellij_bg`, current window inverted to `bg`/`color4`. Right side shows hostname (`color9`) and `%Y-%m-%d %H:%M`. Pane borders inactive `color0`, active `color4`. Message + mode lines use `color4` over `bg`.

### Out-of-scope follow-ups

- `DotFiles/nvim/lua/plugins/zellij-nav.lua` → swap to `christoomey/vim-tmux-navigator` so the Alt-nav chords cross nvim splits.
- `DotFiles/nvim/lua/plugins/sidekick.lua:16` `backend = "zellij"` → `"tmux"`.
- `zj-proj` line 22 calls `zellij action new-tab`; adapt to detect `$TMUX` and call `tmux new-window -c "$sel"` instead.
- `scripts/tmux-sessionizer.sh` is referenced by the `ts` shell alias but doesn't exist yet.

## Zellij (disabled)

`zellij.nix` is no longer imported in `default.nix`; the file is kept on disk so the previous configuration can be restored by uncommenting one line. Related stragglers left in place: `palette.zellij_bg` (reused as the tmux status bg), the `zboot()` zsh function (now dormant), and `zj-proj` (currently wired into tmux via `display-popup` but still uses zellij commands internally).

**Plugins** (remote-URL WASM, fetched on load — no effect while zellij is disabled):
- `autolock` (`fresh2dev/zellij-autolock`) — auto-locks on trigger processes, loaded eagerly via `load_plugins`.
- `zextract` (`codingfragments/zellij-zextract`, v0.4.0+) — tmux-fingers-style hint picker; grabs paths/URLs/hashes/git refs without the mouse. Bound to `Alt-x` (`shared_except "locked"`) → floating popup. Added as the keyboard-copy answer since zellij has no native tmux-style visual-select-yank (maintainer punts to `EditScrollback` → `$EDITOR`, bound `Ctrl-s u`). `fzf-zellij` was evaluated and skipped — no prebuilt wasm, needs a from-source build, and duplicates `zj-proj`.

## Integration

`default.nix` is imported by the parent `modules/common/programs/` module tree, which feeds into `modules/cross-platform/default.nix` for all platforms.
