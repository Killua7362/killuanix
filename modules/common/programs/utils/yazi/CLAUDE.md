# Yazi Module

Home Manager configuration for the [Yazi](https://yazi-rs.github.io/) terminal file manager. Yazi is enabled with zsh shell integration. Settings, keybindings, and theming are managed via TOML files imported from this directory.

## Files

| File | Description |
|---|---|
| `default.nix` | Nix module that enables Yazi, wires in shell integration, imports TOML configs, and declares plugins/flavors. References `settings.toml` via `lib.importTOML` (see note below). |
| `keymap.toml` | Full keymap configuration across all Yazi contexts (manager, tasks, select, input, confirm, completion, help). Uses a Colemak-inspired remapping: `n/e/i/o` replace the default `h/j/k/l` for navigation. |
| `yazi.toml` | Core settings: manager layout (1:4:3 ratio), sort options, preview dimensions, opener definitions (`$EDITOR`, `xdg-open`, `mpv`), file-type association rules, task worker counts, plugin fetcher/preloader/previewer pipeline, and input/confirm dialog positioning. |
| `theme.toml` | Theme overrides layered on top of the `vscode-dark-plus` flavor. Defines colors for manager elements (markers, tabs, counts, borders), status bar, input dialogs, completion popups, task list, help panel, file type icons, and filetype-specific styling rules. |

## Plugins and Flavors

- **Flavor:** `vscode-dark-plus` (from `pkgs.yaziFlavors`), set as the dark theme in `theme.toml`.
- **Plugin:** `mount` (from `pkgs.yaziPlugins`).
- Several additional plugins (`starship`, `jump-to-char`, `relative-motions`) are commented out in `default.nix`.

## Keybinding Layout

The keymap uses a non-standard layout remapping directional keys:

| Action | Key |
|---|---|
| Up | `i` |
| Down | `e` |
| Parent dir | `n` |
| Enter dir | `o` |
| Open file | `l` |
| Insert mode (input) | `u` |
| Undo (input) | `k` |

Search uses `/` (next) and `?` (previous), with `h`/`H` for cycling through results. Sorting is prefixed with `,`, linemode with `m`, copy with `c`, and goto with `g`.

## Note

`default.nix` imports `./settings.toml` but the actual file on disk is `yazi.toml`. This mismatch will cause a build error if not resolved -- either rename `yazi.toml` to `settings.toml` or update the import path in `default.nix`.
