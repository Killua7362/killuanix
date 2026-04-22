# Theming Module

Home Manager module that owns the shared color palette and drives GTK / Qt / Kvantum theming from it. The palette is the single source of truth for terminals (kitty, zellij), shells (starship), the browser (qutebrowser), notes (obsidian), GTK apps (libadwaita / adw-gtk3), and Qt apps (via qt5ct/qt6ct + a custom Kvantum theme). Downstream modules reference it as `config.theme.palette`.

## Files

| File | Description |
|---|---|
| `default.nix` | Aggregator that imports `./palette.nix`, `./matugen.nix`, `./gtk.nix`, and `./qt.nix`. |
| `palette.nix` | Declares `options.theme.palette` (attrset of color strings) and its default values. Cross-platform — no Linux guard. Edit here; rebuild to propagate everywhere. |
| `matugen.nix` | Linux-only. Installs helper packages (`matugen`, `pywalfox-native`, `qt6ct`, `qt5ct`) consumed by DMS's wallpaper-driven theming pipeline. No config is written here — DMS ships its own templates. |
| `gtk.nix` | Linux-only. Writes libadwaita / adw-gtk3 `@define-color` overrides into both `gtk.gtk3.extraCss` and `gtk.gtk4.extraCss`, sourced from `config.theme.palette`. |
| `qt.nix` | Linux-only. Builds a custom Kvantum theme named `KilluaPalette` (KvFlat SVG + palette-driven `.kvconfig`) and wires qt5ct/qt6ct to use it, with the Qt palette written as a fallback `static.conf` color scheme. |

## Palette (palette.nix)

`options.theme.palette` is an `attrsOf str`. The default set is grouped as:

- **Base** — `fg`, `bg`, `cursor`, `cursor_text`, `selection_fg`, `selection_bg`, `url`
- **ANSI 16** — `color0` through `color15`
- **Zellij-specific** — `zellij_bg` (slightly different bg from kitty)
- **Qutebrowser / surface family** (Natsumi-derived) — `surface`, `surface_alt`, `surface_low`, `surface_high`, `outline`, `selection`, `selection_strong`, `fg_bright`, `fg_dim`, `fg_dimmer`, `fg_muted`, `error`

Terminal/shell/browser/notes modules read these keys directly from `config.theme.palette`; starship inherits terminal colors, so it follows kitty automatically.

## Static vs dynamic theming

Two theming pipelines coexist and are kept separate on purpose:

- **Static palette (this module)** — `palette.nix` powers kitty, zellij, starship, qutebrowser, obsidian, GTK (`gtk.nix`), and Qt/Kvantum (`qt.nix`). Values are fixed at rebuild time.
- **Dynamic wallpaper-driven (DMS)** — DMS (dank-material-shell, see [`../desktop/hyprland/dms.nix`](../desktop/hyprland/dms.nix)) owns the matugen pipeline and ships its own templates for kitty, GTK3/4, qt5ct/qt6ct, firefox userChrome, and pywalfox. `matugen.nix` only installs the detection-gated helper packages so DMS can pick them up.

Wallpaper-driven theming for kitty / starship / zellij / qutebrowser is intentionally disabled — those apps use the static palette so the look stays stable across wallpaper changes. Firefox addon wiring lives in `browsers/firefox/default.nix`.

## GTK (gtk.nix)

Writes a single `gtkCss` string into both `gtk.gtk3.extraCss` and `gtk.gtk4.extraCss`. Overrides cover libadwaita / adw-gtk3 named colors: `accent`, `destructive`, `success`, `warning`, `error` (each with `_color` / `_bg_color` / `_fg_color` variants), plus `window`, `view`, `headerbar`, `sidebar`, `secondary_sidebar`, `card`, `dialog`, `popover`, `thumbnail`, `shade_color`, and `scrollbar_outline_color`. All values come from `config.theme.palette`.

## Qt / Kvantum (qt.nix)

- **Kvantum theme** — `KilluaPalette` is written to `~/.config/Kvantum/KilluaPalette/`. The widget SVG is reused from `pkgs.qt6Packages.qtstyleplugin-kvantum`'s KvFlat theme, while `.kvconfig`'s `[GeneralColors]` block is overridden from the palette (window, base, button, light, mid, dark, highlight, text, disabled text, tooltip text, link, visited link, etc.). `~/.config/Kvantum/kvantum.kvconfig` selects `KilluaPalette`.
- **qt5ct / qt6ct** — written as a safety net for apps that bypass Kvantum. `static.conf` holds a `[ColorScheme]` with `active_colors` / `disabled_colors` / `inactive_colors` derived from the palette; `qt5ct.conf` / `qt6ct.conf` point `style=kvantum` with `custom_palette=true` and `icon_theme=Adwaita`.
- **Packages** — installs `libsForQt5.qtstyleplugin-kvantum` and `qt6Packages.qtstyleplugin-kvantum`.
- **Forced options** — `qt.platformTheme.name = "qtct"` and `qt.style = "kvantum"` via `lib.mkForce`.
- **Session variables** (`lib.mkForce`) — `QT_QPA_PLATFORMTHEME=qt5ct`, `QT_QPA_PLATFORMTHEME_QT6=qt6ct`, `QT_STYLE_OVERRIDE=kvantum-dark`.

## Matugen helpers (matugen.nix)

Linux-only. Just installs packages so DMS's pipeline works out of the box:

- `matugen` — color extractor (in case DMS doesn't bring it)
- `pywalfox-native` — firefox dynamic theming (still needs the addon + `pywalfox install` once)
- `qt6Packages.qt6ct` / `libsForQt5.qt5ct` — so DMS can detect and theme Qt6 / Qt5 apps

No templates or config files are written here; DMS owns all of that.

## Integration

`default.nix` is imported by `modules/common/programs.nix`, which is aggregated into `modules/cross-platform/default.nix` — the main Home Manager entry point every platform (chrollo, killua, archnix, macnix) pulls in. Importing this module registers `options.theme.palette`, so any other Home Manager module can read `config.theme.palette.<key>` without extra wiring.
