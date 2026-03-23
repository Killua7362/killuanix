# Editors Module

Configures code editors shared across all platforms. Imported by `modules/common/programs.nix`.

## Files

| Path | Description |
|---|---|
| `default.nix` | Module entry point; imports `./neovim` and `./zed.nix` |
| `zed.nix` | Zed editor configuration: vim mode with sneak, extensions (nix, toml, lua, basher, dracula, opencode), vim-style keybindings (space-leader), LSP setup for nixd and rust-analyzer (with clippy, inlay hints, proc macros), formatters (prettier for Markdown/JSON, taplo for TOML), terminal settings, and node.js path from Nix |
| `neovim/` | nixCats-based Neovim configuration with LazyVim; see `neovim/CLAUDE.md` for full details |

## Submodules

- **`neovim/`** -- Full Neovim setup documented in [`neovim/CLAUDE.md`](neovim/CLAUDE.md)

## Integration

`default.nix` is a simple aggregator:

```nix
{
  imports = [
    ./neovim
    ./zed.nix
  ];
}
```

Both editors are enabled unconditionally for all platforms that import this module. The Zed config uses `programs.zed-editor.enable = true` (Home Manager option). Neovim uses `nixCats.enable = true` (nixCats Home Manager module).
