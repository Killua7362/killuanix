# Dev Module

Home Manager module for development tools shared across all platforms (NixOS, Arch, macOS).

## Files

| File | Description |
|---|---|
| `default.nix` | Aggregator that imports `git.nix`, `lazygit.nix`, `opencode.nix`, and `claude.nix`. |
| `git.nix` | Git configuration. Sets user identity from `commonModules.user.userConfig`. Includes a conditional include for Azure DevOps repos that swaps in Boeing credentials (decrypted via sops) and routes traffic through a SOCKS5 proxy at `127.0.0.1:1080`. |
| `lazygit.nix` | Lazygit configuration. Defines a full custom keybinding map covering universal navigation, file staging, branch operations, commits, stash, submodules, and merge conflict resolution. |
| `claude.nix` | Enables the `claude-code` Home Manager program module. No additional settings beyond `enable = true`. |
| `opencode.nix` | Enables the `opencode` program using the package from the `opencode-flake` input. Configures a custom provider (`gl4f`) backed by an OpenAI-compatible API at `g4f.space` with the `minimaxai/minimax-m2.1` model. |

## Notable Configuration Details

- **Git identity**: Default user name and email come from `inputs.self.commonModules.user.userConfig`. Azure DevOps repos get a separate identity injected via a sops template at `~/.config/git/config-azure`, matched with `hasconfig:remote.*.url:https://dev.azure.com/**`.
- **Git Azure proxy**: HTTPS requests to `dev.azure.com` are routed through `socks5h://127.0.0.1:1080`.
- **Lazygit keybindings**: Extensively remapped (e.g., `i`/`e` for prev/next item, `n`/`o` for prev/next block, `h`/`H` for next/prev search match). This suggests a Colemak or similar non-QWERTY keyboard layout.
- **OpenCode provider**: Uses a custom `gl4f` provider pointing to `https://g4f.space/api/nvidia` with the MiniMax M2.1 model.

## Integration

`default.nix` is imported by the parent `modules/common/programs/` module tree, which is ultimately pulled into `modules/cross-platform/default.nix` for all platforms.
