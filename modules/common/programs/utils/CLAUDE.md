# Utils Module

Utility program configurations shared across all platforms. Imported by `modules/common/programs.nix` as part of the common Home Manager module set.

## Files

| File | Description |
|---|---|
| `default.nix` | Aggregator module that imports `./yazi`, `./zathura.nix`, `./dots.nix`, `./nemo.nix`, `./mimeapps.nix`, `./clipboard-menu.nix`, and `./clipboard-history.nix`. |
| `zathura.nix` | Configures the Zathura PDF/document viewer (Linux-only via `mkDefault`). Not registered as the default PDF handler — `mimeapps.nix` keeps `org.gnome.Papers.desktop` for `application/pdf`. Sets smooth scrolling, clipboard integration, JetBrainsMono Nerd Font Mono at size 15, and a full set of Colemak-remapped keybindings (`e`/`i` for scroll down/up, `n`/`o` for left/right, `h` for previous page). Includes index navigation and presentation toggle bindings. |
| `dots.nix` | Manages dotfile symlinks via `xdg.configFile`. Currently symlinks `.lesskey` from the `DotFiles/macnix/` submodule directory. |
| `nemo.nix` | Linux-only (`lib.mkIf pkgs.stdenv.isLinux`). Installs `nemo-with-extensions` (fileroller, emblems, python) plus `file-roller`, `webp-pixbuf-loader`, and `ffmpegthumbnailer`. Configures Nemo via `dconf.settings` (list view default, editable path bar, ISO dates, JetBrainsMono Nerd Font 11, kitty as terminal). Registers `nemo.desktop` for `application/x-gnome-saved-search`. |
| `mimeapps.nix` | Linux-only. Declares `xdg.mimeApps.defaultApplications` for browser (`firefox-nightly`), directories (`nemo`), images (`org.gnome.Loupe`), audio/video (`mpv`), text/code (`nvim`), PDFs (`org.gnome.Papers`), and archives (`org.gnome.FileRoller`). |
| `clipboard-menu.nix` | Linux-only wofi-driven secret paster. Scans the `clipboard:` block of `secrets/personal.yaml` at evaluation time to discover keys (plaintext; only values are sops-encrypted), declares a sops secret at `clipboard/<key>` for each, and builds a `clipboard-menu` shell app (`pkgs.writeShellApplication`) that pops a themed wofi dmenu and `wl-copy`s the chosen secret to the clipboard (copy-only — no auto-paste; user pastes manually). Bound to `Super+C` in Hyprland. **Passwords only** — general clipboard history is `clipboard-history.nix`. |
| `clipboard-history.nix` | Linux-only general clipboard-history picker (`clipboard-history` shell app), bound to `Super+V` in Hyprland. `cliphist list \| wofi \| cliphist decode \| wl-copy` over the cliphist store fed by `hyprland/clipboard.nix`'s text+image watchers. Handles **both text and images**: image entries are decoded to a temp thumbnail and rendered as previews via wofi's `img:PATH:text:LABEL` markup (`allow_images=true`); text entries pass through with their `<id>\t` prefix. Selecting either re-copies the real data (copy-only — no auto-paste). The list is capped at the newest **100** entries for a fast open (`head -n 100`; cliphist's own store keeps up to its 750 `-max-items` default); `clipboard-history --all` skips the cap to fuzzy-search the whole store — there is no dedicated cliphist GUI (vicinae/DMS clipboards read their own separate stores). Uses the same `config.theme.palette` wofi CSS as `clipboard-menu.nix` (taller window for thumbnails). Runtime deps: cliphist, wofi, wl-clipboard, coreutils, gnugrep. Replaced the previous `vicinae` clipboard mapping on `Super+V`. |

## Clipboard Menu

The entry list is generated at Nix eval time by scanning `secrets/personal.yaml` for 4-space-indented `key:` lines under the top-level `clipboard:` block. Each discovered key (e.g. `github_token`) becomes a sops secret at path `clipboard/<key>` and a title-cased menu entry (`"Github Token"`) — adding a new `clipboard/foo` entry to `secrets/personal.yaml` is all that's needed to expose it. Wofi colors, fonts, and borders are generated from `config.theme.palette` (JetBrainsMono Nerd Font, `bg`/`fg`/`selection_*`/`color0`/`color4`/`color8`), so the picker re-themes automatically with the rest of the palette. Runtime dependencies: wofi, wl-clipboard, libnotify, coreutils.

## Submodules

- **`yazi/`** -- Yazi terminal file manager configuration. See [`yazi/CLAUDE.md`](yazi/CLAUDE.md) for details on plugins, keybindings, and theme settings.

## Integration

`default.nix` is the entry point imported by the parent `modules/common/programs.nix` module. It re-exports all sub-modules so that adding or removing a utility program here automatically propagates to every platform's Home Manager configuration.
