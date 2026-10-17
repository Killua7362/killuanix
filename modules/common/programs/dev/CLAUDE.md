# Dev Module

Home Manager module for general development tools (git + lazygit) shared across all platforms (NixOS, Arch, macOS). All AI/Claude tooling lives in the [`ai/`](./ai/CLAUDE.md) subdirectory.

## Files

| File | Description |
|---|---|
| `default.nix` | Aggregator that imports `git.nix`, `lazygit.nix`, and the `ai/` subdirectory. |
| `git.nix` | Git + GitHub CLI configuration. Sets user identity from `commonModules.user.userConfig`. Enables `extensions.worktreeConfig` globally so ccmanager (in `ai/`) can persist per-worktree config (e.g. `ccmanager.parentBranch`). Conditional `includes` swap in alternate identities (each rendered as a sops template under `~/.config/git/`): Azure DevOps repos use Boeing credentials (`boeing/git_{name,email}`); `gitlab-ext.digitalaviationservices.com` repos use DAS credentials (`das/git_{name,email}`, with three URL-form variants — `https://host/…`, `https://user@host/…`, `git@host:…`). HTTPS to both hosts is routed through SOCKS5 at `127.0.0.1:1080`. Also configures `programs.gh` (GitHub CLI): SSH protocol, nvim editor, and aliases `co`/`pv`/`rv`. Authentication is done interactively via `gh auth login` — credentials land in `~/.config/gh/hosts.yml` and are not managed by Nix. |
| `lazygit.nix` | Lazygit configuration. Defines a full custom keybinding map covering universal navigation, file staging, branch operations, commits, stash, submodules, and merge conflict resolution. |
| `ai/` | All AI/Claude tooling — Claude Code, OpenCode, ccmanager, ccr, ruflo, claude-flow, claude-kit, claude-launchers, claude-resources, MCP servers (jupyter-env-mcp), and the local skill bundle. See [`ai/CLAUDE.md`](./ai/CLAUDE.md). |

## Notable Configuration Details

- **Git identity**: Default user name and email come from `inputs.self.commonModules.user.userConfig`. Per-host identities are injected via sops templates under `~/.config/git/`: Azure DevOps repos (`config-azure`, keys `boeing/git_{name,email}`) matched with `hasconfig:remote.*.url:https://*@dev.azure.com/**`; DAS GitLab repos (`config-das`, keys `das/git_{name,email}`) matched with three variants of `gitlab-ext.digitalaviationservices.com`. Adding another host = new sops keys in `modules/common/sops.nix` + new `sops.templates."config-<host>"` block + new `includes` entries.
- **Claude-only read-only git credentials**: `git.nix` sets `local.claudeExtraEnv` (declared in `ai/claude.nix`), which `overlayClaude` applies via `bwrap --setenv` **inside Claude's sandbox only**. It injects `GIT_CONFIG_COUNT`/`GIT_CONFIG_KEY_n`/`GIT_CONFIG_VALUE_n` (highest config precedence) to set per-host credential helpers for `dev.azure.com` and `gitlab-ext.digitalaviationservices.com`. Each host gets an empty helper first, which clears inherited helpers, then a tiny `git-credential-ro-*` script that answers `get` with the read-only PAT from sops (`boeing/azure_token`, `boeing/gitlab_token`) and ignores `store`/`erase`. So claude can `git pull`/`fetch`, and its pushes fail server-side. The user's terminal never sees these helpers, so manual pushes use the user's own write token. Also sets `GIT_ASKPASS=false` + `GIT_TERMINAL_PROMPT=0` in the sandbox. **Gotcha:** outside claude, git falls back to `SSH_ASKPASS=ksshaskpass`, which saves answers in KWallet and replays them silently. Without the askpass override, a failing RO helper would let claude pull the KWallet-saved **write** token. Note that claude can still reach KWallet over D-Bus or by running `ksshaskpass` directly; for a hard guarantee, don't let KWallet remember the write token. The Linux-only `--setenv` path means this does nothing on macnix.
- **Git proxy hosts**: HTTPS requests to `dev.azure.com` and `gitlab-ext.digitalaviationservices.com` are routed through `socks5h://127.0.0.1:1080` via per-host `http "<url>".proxy` entries.
- **`worktreeConfig` extension**: Set here (not in `ai/ccmanager.nix`) because it's a global git setting; ccmanager is the primary consumer but the toggle naturally lives with the rest of the git config.
- **Lazygit keybindings**: Extensively remapped (e.g., `i`/`e` for prev/next item, `n`/`o` for prev/next block, `h`/`H` for next/prev search match). This suggests a Colemak or similar non-QWERTY keyboard layout.

## Integration

`default.nix` is imported by the parent `modules/common/programs/` module tree, which is ultimately pulled into `modules/cross-platform/default.nix` for all platforms.
