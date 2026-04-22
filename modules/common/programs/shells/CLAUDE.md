# Shells Module

Home Manager configuration for shell environments (fish, zsh) and the starship cross-shell prompt. Both shells share a largely identical set of aliases, environment variables, and helper functions, kept in sync manually.

## Files

| File | Description |
|---|---|
| `default.nix` | Aggregator that imports `fish.nix`, `zsh.nix`, and `starship.nix`. |
| `fish.nix` | Fish shell configuration: aliases, custom functions, environment variables, shell init script. |
| `zsh.nix` | Zsh shell configuration: aliases, session variables, antidote plugin manager, completion styles, key bindings, init script. |
| `starship.nix` | Starship prompt settings: per-language symbols, git branch/status formatting, nix-shell indicator, battery, memory usage, directory style. |

## Shell Aliases (shared across fish and zsh)

Both shells define the same core alias set:

- `ls`/`la`/`ll`/`lst`/`llt`/`tree` -- `eza` (fish uses the older `exa` binary name) with color, grouping, and classification.
- `cp`, `mv`, `ln`, `mkdir` -- verbose/interactive safety wrappers.
- `c` (clear), `d` (nvim diff), `svim` (sudoedit).
- `t`/`tl`/`tn`/`ts`/`ta`/`td` -- tmux attach/list/new/sessionizer/kill shortcuts.
- `sysu`/`jnsu` -- `systemctl --user` and `journalctl --user`.
- `oil` -- runs `DotFiles/scripts/oil-ssh.sh`.

## Custom Functions

Defined in both shells:

- `pacsave` / `pacapply` -- run `aconfmgr` save/apply for Arch native package tracking.

`nix_switch` used to be defined in both shells; it now lives as a standalone script at `~/killuanix/scripts/nix_switch` (on PATH via the scripts dir). Supports `home` / `system` / `both` modes, `--host chrollo|killua|archnix` (autodetected from `/etc/hostname` + `/etc/arch-release` when omitted), and a `--limit` flag that applies `--max-jobs 2 --cores 2` plus a `systemd-run --user --scope` cgroup cap (CPU 200%, memory 4G) for builds that should not starve the interactive session.

Zsh-only:

- `boeingvpn` -- connects via `openconnect` with SOCKS proxy (`ocproxy`).
- `chrome-socks` -- launches Chrome through the SOCKS proxy.
- `opencode` -- runs opencode in a rootless podman container with bind mounts.
- `ta`/`td` -- tmux attach/kill wrappers (needed as functions for argument passing).

## Zsh Details

- **Plugin manager**: Antidote (`programs.zsh.antidote`), with `useFriendlyNames = true`.
- **Plugins** (notable): `zsh-vi-mode`, `fzf-tab`, `fzf-history-search`, `ugit`, `enhancd`, `fast-syntax-highlighting`, `zsh-autosuggestions`, `zsh-completions`, `forgit`, plus several oh-my-zsh library modules (extract, colored-man-pages, globalias, magic-enter, fancy-ctrl-z, zoxide, git, golang, python).
- **Completion**: `compinit` loaded manually in `initContent`; completion disabled via HM (`enableCompletion = false`). Custom `zstyle` rules for case-insensitive matching and fzf-tab preview with `eza`.
- **History**: 10000 entries, dedup enabled, shared across sessions.
- **Key bindings**: vi-insert mode bindings for Home/End, Ctrl+Right/Left word movement, Ctrl+C break. `fzf_history_search` is rebound after `zsh-vi-mode` init via `zvm_after_init`.
- **Init order**: HM session vars sourced first, then PATH additions, then `starship init zsh` and `zoxide init zsh`.

## Fish Details

- **Plugins**: All commented out (z, fifc, fzf-fish, nvm).
- **Shell init**: Runs `starship init fish` and `zoxide init fish` via `shellInit`. Sets fish-specific color variables and disables greeting.
- **Environment variables**: Set via `set -gx` / `set -x` in `shellInit` rather than HM's `sessionVariables`.

## Starship Prompt

- Enabled by default (`lib.mkDefault true`), with zsh integration explicitly enabled.
- Custom Nerd Font symbols for most language detectors (Go, Rust, Python, Node, Java, Ruby, etc.).
- Git branch: dimmed white with branch icon. Git status: uses unicode symbols for ahead/behind/modified/staged/deleted/etc.
- Nix shell indicator: lambda for pure, lozenge for impure.
- Memory usage and exit status modules are enabled (not disabled).
- Directory style: cyan, with lock icon for read-only.

## Integration

`default.nix` is imported by the parent `modules/common/programs/` module tree, which is in turn pulled into `modules/cross-platform/default.nix` for all platforms.
