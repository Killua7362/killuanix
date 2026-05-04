# Dev Module

Home Manager module for general development tools (git + lazygit) shared across all platforms (NixOS, Arch, macOS). All AI/Claude tooling lives in the [`ai/`](./ai/CLAUDE.md) subdirectory.

## Files

| File | Description |
|---|---|
| `default.nix` | Aggregator that imports `git.nix`, `lazygit.nix`, and the `ai/` subdirectory. |
| `git.nix` | Git + GitHub CLI configuration. Sets user identity from `commonModules.user.userConfig`. Enables `extensions.worktreeConfig` globally so ccmanager (in `ai/`) can persist per-worktree config (e.g. `ccmanager.parentBranch`). Includes a conditional include for Azure DevOps repos that swaps in Boeing credentials (decrypted via sops) and routes traffic through a SOCKS5 proxy at `127.0.0.1:1080`. Also configures `programs.gh` (GitHub CLI): SSH protocol, nvim editor, and aliases `co`/`pv`/`rv`. Authentication is done interactively via `gh auth login` — credentials land in `~/.config/gh/hosts.yml` and are not managed by Nix. |
| `lazygit.nix` | Lazygit configuration. Defines a full custom keybinding map covering universal navigation, file staging, branch operations, commits, stash, submodules, and merge conflict resolution. |
| `ai/` | All AI/Claude tooling — Claude Code, OpenCode, ccmanager, ccr, ruflo, claude-flow, claude-kit, claude-resources, MCP servers (code-index, jupyter-env-mcp), and the local skill bundle. See [`ai/CLAUDE.md`](./ai/CLAUDE.md). |

## Notable Configuration Details

- **Git identity**: Default user name and email come from `inputs.self.commonModules.user.userConfig`. Azure DevOps repos get a separate identity injected via a sops template at `~/.config/git/config-azure`, matched with `hasconfig:remote.*.url:https://dev.azure.com/**`.
- **Git Azure proxy**: HTTPS requests to `dev.azure.com` are routed through `socks5h://127.0.0.1:1080`.
- **`worktreeConfig` extension**: Set here (not in `ai/ccmanager.nix`) because it's a global git setting; ccmanager is the primary consumer but the toggle naturally lives with the rest of the git config.
- **Lazygit keybindings**: Extensively remapped (e.g., `i`/`e` for prev/next item, `n`/`o` for prev/next block, `h`/`H` for next/prev search match). This suggests a Colemak or similar non-QWERTY keyboard layout.

## Integration

`default.nix` is imported by the parent `modules/common/programs/` module tree, which is ultimately pulled into `modules/cross-platform/default.nix` for all platforms.
