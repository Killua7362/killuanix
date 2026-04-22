# Utils Module

Utility program configurations shared across all platforms. Imported by `modules/common/programs.nix` as part of the common Home Manager module set.

## Files

| File | Description |
|---|---|
| `default.nix` | Aggregator module that imports `./yazi`, `./zathura.nix`, `./dots.nix`, `./nemo.nix`, and `./mimeapps.nix`. |
| `zathura.nix` | Configures the Zathura PDF/document viewer (Linux-only via `mkDefault`). Not registered as the default PDF handler — `mimeapps.nix` keeps `org.gnome.Papers.desktop` for `application/pdf`. Sets smooth scrolling, clipboard integration, JetBrainsMono Nerd Font Mono at size 15, and a full set of Colemak-remapped keybindings (`e`/`i` for scroll down/up, `n`/`o` for left/right, `h` for previous page). Includes index navigation and presentation toggle bindings. |
| `dots.nix` | Manages dotfile symlinks via `xdg.configFile`. Currently symlinks `.lesskey` from the `DotFiles/macnix/` submodule directory. |
| `nemo.nix` | Linux-only (`lib.mkIf pkgs.stdenv.isLinux`). Installs `nemo-with-extensions` (fileroller, emblems, python) plus `file-roller`, `webp-pixbuf-loader`, and `ffmpegthumbnailer`. Configures Nemo via `dconf.settings` (list view default, editable path bar, ISO dates, JetBrainsMono Nerd Font 11, ghostty as terminal). Registers `nemo.desktop` for `application/x-gnome-saved-search`. |
| `mimeapps.nix` | Linux-only. Declares `xdg.mimeApps.defaultApplications` for browser (`firefox-nightly`), directories (`nemo`), images (`org.gnome.Loupe`), audio/video (`mpv`), text/code (`nvim`), PDFs (`org.gnome.Papers`), and archives (`org.gnome.FileRoller`). |

## Submodules

- **`yazi/`** -- Yazi terminal file manager configuration. See [`yazi/CLAUDE.md`](yazi/CLAUDE.md) for details on plugins, keybindings, and theme settings.

## Integration

`default.nix` is the entry point imported by the parent `modules/common/programs.nix` module. It re-exports all sub-modules so that adding or removing a utility program here automatically propagates to every platform's Home Manager configuration.
