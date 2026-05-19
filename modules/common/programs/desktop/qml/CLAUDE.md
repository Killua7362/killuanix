# QML Workspace

Drop-in folder for custom DankMaterialShell plugins and standalone QML widgets. Open neovim here to edit `.qml` with `qmlls6` LSP wired up for stock Qt, Quickshell, and DMS internals (`qs.*`).

## Files

| Path | Purpose |
|---|---|
| `default.nix` | HM module. Installs `pkgs.kdePackages.qtdeclarative` (qmlls6 + Qt6 QML modules) and ships `home.activation.qmlWorkspaceImportTree` — a bash builder that synthesizes `~/.cache/qml-workspace/qs/<Module>/qmldir` from `${dms}/quickshell/`. Writes the Qt6 QML path to `~/.cache/qml-workspace/QT_QML_PATH` for `.envrc` to pick up. |
| `.envrc` | direnv: exports `QML_IMPORT_PATH` = cache root + Qt6 QML dir, so `qmlls6 -E` finds `qs.*` and `QtQuick.*` imports. Loaded automatically when you `cd` into this folder (or any subdir) in a direnv-enabled shell. |
| `leader-hud/` | DMS bar pill widget showing the active Hyprland leader submap. Wired into `programs.dank-material-shell.plugins.leaderHud.src` from `../hyprland/dms/default.nix`. Reads `~/.cache/leader-hud/{state,submaps.json}` written by `hyprland/leader.nix`. |

## Why the synthesized import tree

`qs.Common`, `qs.Widgets`, `qs.Modules.Plugins`, etc. are **Quickshell-runtime** imports — Quickshell rewrites `qs.` to the shell config root at load time. DMS ships no `qmldir` files, so stock qmlls (which is Qt-spec, not Quickshell-aware) cannot resolve them.

The activation script walks `${inputs.dms}/quickshell/`, for every TitleCase subdir generates a `qmldir`:

```
module qs.Common
singleton Theme 1.0 Theme.qml
PrayerCheckbox 1.0 PrayerCheckbox.qml
…
```

and symlinks the original `.qml` files alongside. `singleton` keyword is added when the source's first line is `pragma Singleton`. Result: qmlls sees a Qt-spec-compliant module tree at `~/.cache/qml-workspace/qs/`, and `gd` on `Theme.surfaceText` jumps into the real upstream file.

Cache is wiped + rebuilt on every `nix_switch` (cheap; ~hundreds of symlinks + small text files). When the `dms` flake input bumps, the activation re-runs because the nix-baked store path changes.

## Adding a new custom plugin

1. Create the folder: `mkdir leader-hud-v2/` and drop your `*.qml` files.
2. Wire it in `../hyprland/dms/default.nix`:
   ```nix
   programs.dank-material-shell.plugins.leaderHudV2 = {
     enable = true;
     src = ../../qml/leader-hud-v2;
   };
   ```
3. `scripts/nix_switch` to activate. DMS reads the plugin on next launch (cache busts via `dmsQmlcacheBust` activation already in `dms/default.nix`).

## Editing flow

```sh
cd modules/common/programs/desktop/qml/leader-hud
# direnv loads .envrc → QML_IMPORT_PATH set
nvim LeaderHudWidget.qml
# :LspInfo should show qmlls6 attached
```

If LSP claims `qs.Common module not found`, the cache is missing or stale — run `scripts/nix_switch` and reopen the file.

## Integration

`default.nix` is imported from `../default.nix` (the desktop module aggregator). No nixos/Darwin gating — the module is Linux-only by virtue of `kdePackages.qtdeclarative` availability and the `inputs.dms` dependency, but it's safe to include on every HM host that imports the desktop tree.
