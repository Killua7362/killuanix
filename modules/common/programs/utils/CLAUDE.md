# Utils Module

Utility program configurations shared across all platforms. Imported by `modules/common/programs.nix` as part of the common Home Manager module set.

## Files

| File | Description |
|---|---|
| `default.nix` | Aggregator module that imports `./yazi`, `./zathura.nix`, and `./dots.nix`. |
| `zathura.nix` | Configures the Zathura PDF/document viewer. Enables smooth scrolling, clipboard integration, JetBrainsMono Nerd Font at size 15, and a full set of Colemak-remapped keybindings (`e`/`i` for scroll down/up, `n`/`o` for left/right, `h` for previous page). Includes index navigation and presentation toggle bindings. |
| `dots.nix` | Manages dotfile symlinks via `xdg.configFile`. Currently symlinks `.lesskey` from the `DotFiles/macnix/` submodule directory. |

## Submodules

- **`yazi/`** -- Yazi terminal file manager configuration. See [`yazi/CLAUDE.md`](yazi/CLAUDE.md) for details on plugins, keybindings, and theme settings.

## Integration

`default.nix` is the entry point imported by the parent `modules/common/programs.nix` module. It re-exports all three sub-modules so that adding or removing a utility program here automatically propagates to every platform's Home Manager configuration.
