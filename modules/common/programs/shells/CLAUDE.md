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
- `oil` -- runs `DotFiles/scripts/v1/oil-ssh.sh`.

## Custom Functions

Defined in both shells:

- `pacsave` / `pacapply` -- run `aconfmgr` save/apply for Arch native package tracking.

`nix_switch` used to be defined in both shells; it now lives as a standalone script at `~/killuanix/DotFiles/scripts/personal/nix_switch` (on PATH via the `DotFiles/scripts/personal` dir). Supports `home` / `system` / `both` modes, `--host chrollo|killua|archnix` (autodetected from `/etc/hostname` + `/etc/arch-release` when omitted), and a `--limit` flag that applies `--max-jobs 2 --cores 2` plus a `systemd-run --user --scope` cgroup cap (CPU 200%, memory 4G) for builds that should not starve the interactive session.

Zsh-only:

- `boeingvpn [userid] [gateway-host]` -- connects via `openconnect` with SOCKS proxy (`ocproxy`). `--user` defaults to the `boeing/vpn_userid` sops secret (read at runtime from its decrypted path); pass `$1` to override. Gateway auto-picked by probing all GP gateways for lowest **median** TCP-connect RTT (TLS skipped — Boeing gateways require unsafe legacy renegotiation); override with `$2` or `$BOEINGVPN_GATEWAY`. Probe tunables: `BOEINGVPN_SAMPLES` (default 3), `BOEINGVPN_DEADLINE` (default 15s hard wall-clock cap — stops probing and uses best-so-far), `BOEINGVPN_CONNECT_TIMEOUT` (default 2s/connect). A down gateway is dropped after 2 leading failures (not 1 — the cold DNS sample can exceed the timeout on a healthy gateway). Standalone ranking tool: `gp-fastest-gateway.sh` (`SAMPLES`/`DEADLINE`/`CONNECT_TIMEOUT` env knobs).
- `chrome-socks` -- launches Chrome through the SOCKS proxy.
- `opencode` -- runs opencode in a rootless podman container with bind mounts.
- `ta`/`td` -- tmux attach/kill wrappers (needed as functions for argument passing).
- `zboot` -- boots three zellij sessions in parallel (`killuanix` in `~/killuanix`, `bdsi` + `mod` in `~`) and foreground-attaches to `killuanix`. Background sessions spawn detached via `script -qfc` because zellij refuses to run without a tty; `&!` disowns them. Idempotent: skips creation if `zellij list-sessions -s` already lists the name.

## Zsh Details

- **Plugin manager**: Antidote (`programs.zsh.antidote`), with `useFriendlyNames = true`.
- **Plugins** (notable): `zsh-vi-mode`, `fzf-tab`, `fzf-history-search`, `ugit`, `enhancd`, `fast-syntax-highlighting`, `zsh-autosuggestions`, `zsh-completions`, `forgit`, plus several oh-my-zsh library modules (extract, colored-man-pages, globalias, magic-enter, fancy-ctrl-z, zoxide, git, golang, python).
- **Completion**: `compinit` loaded manually in `initContent`; completion disabled via HM (`enableCompletion = false`). Custom `zstyle` rules for case-insensitive matching and fzf-tab preview with `eza`.
- **History**: 10000 entries, dedup enabled, shared across sessions.
- **Key bindings**: vi-insert mode bindings for Home/End, Ctrl+Right/Left word movement, Ctrl+C break. `fzf_history_search` is rebound after `zsh-vi-mode` init via `zvm_after_init`.
- **Init order**: HM session vars sourced first, then PATH additions, then `starship init zsh` and `zoxide init zsh`.
- **WezTerm autolock hook**: when `$WEZTERM_PANE` is set, a `preexec`/`precmd` pair emits an OSC 1337 `WEZTERM_PROG` user var naming the running foreground command (cleared at the prompt). WezTerm's modal-chord passthrough (see `terminal/CLAUDE.md` → WezTerm → Autolock) reads it — this is the only per-command signal that crosses the `wezterm connect unix` mux. forgit aliases are marked `fzf` by inspecting `type` output so their fzf UI locks like nvim does.

## Fish Details

- **Disabled** (`programs.fish.enable = false`): zsh is the login shell on all hosts, so fish is not built. The config below is retained for reference / re-enable. With fish off, the HM fish module no longer forces `programs.man.generateCaches`, so the explicit `false` is a no-op guard (matters only if fish is re-enabled).
- **Plugins**: All commented out (z, fifc, fzf-fish, nvm).
- **Shell init**: Runs `starship init fish` and `zoxide init fish` via `shellInit`. Sets fish-specific color variables and disables greeting.
- **Environment variables**: Set via `set -gx` / `set -x` in `shellInit` rather than HM's `sessionVariables`.
- **`programs.man.generateCaches = false`**: overrides the `mkDefault true` the HM fish module pulls in for `apropos`. That default rebuilds the mandb whatis index (the slow `man-cache>` derivation, visible during `nix_switch`) whenever man paths change. We don't use `apropos`/`man -k`; fish tab-completions come from `generated_completions` and are unaffected by disabling it.

## Starship Prompt

- Enabled by default (`lib.mkDefault true`), with zsh integration explicitly enabled.
- Custom Nerd Font symbols for most language detectors (Go, Rust, Python, Node, Java, Ruby, etc.).
- Git branch: dimmed white with branch icon. Git status: uses unicode symbols for ahead/behind/modified/staged/deleted/etc.
- Nix shell indicator: lambda for pure, lozenge for impure.
- Memory usage and exit status modules are enabled (not disabled).
- Directory style: cyan, with lock icon for read-only.

## Integration

`default.nix` is imported by the parent `modules/common/programs/` module tree, which is in turn pulled into `modules/cross-platform/default.nix` for all platforms.
