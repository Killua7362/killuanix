# Kodi Module

Home Manager module for Kodi media center with custom addons, Arctic Fuse skin, and declarative configuration. Linux-only (`kodi-wayland`).

## Files

| File | Description |
|---|---|
| `default.nix` | Main entry point; builds the addon bundle, launcher wrapper, activation scripts (skin deploy, addon DB bootstrap, secret injection), and file manager sources |
| `addons.nix` | Custom Kodi addon derivations not in nixpkgs — imported as a plain attrset (not a NixOS/HM module) |
| `widgets.nix` | Declarative skinvariables JSON node configs for home widgets, submenus, power menu, and search widgets |

## Skin

**Arctic Fuse 3** (`skin.arctic.fuse.3`) — built as a Nix derivation, then copied to `~/.kodi/addons/` at activation time (writable) so `skinvariables` can generate XML includes into it. Spotlight defaults are patched to use TMDb trending.

## Addon Categories

- **Repositories:** Umbrella, jurialmunkey, CocoScrapers, nixgates
- **Video:** Umbrella, FenLight, Seren, TMDb Helper
- **Tracking:** Trakt (from nixpkgs), Simkl
- **Scrapers:** CocoScrapers
- **Subtitles:** a4ksubtitles (from nixpkgs)
- **Utilities:** Open Wizard, inputstream-adaptive, YouTube (from nixpkgs)
- **Seren deps:** unidecode, beautifulsoup4, soupsieve, context-seren, myconnpy

## Launcher

`kodiWrapped` is a `symlinkJoin` that replaces the `kodi` binary with a shell script that:
1. Bootstraps/updates the Addons SQLite DB (creates schema + enables managed addons)
2. Configures `guisettings.xml` (unknown sources, no addon notifications, update mode)
3. Resets skinvariables generator hash to force shortcut rebuild
4. Sets SSL cert env vars for Python addons
5. Launches Kodi, then cleans up zombie processes on exit

## Activation Scripts

- **`kodiSkin`** — copies Arctic Fuse skin to writable `~/.kodi/addons/`, patches spotlight defaults
- **`kodiEnableAddons`** — enables managed addons in an existing Addons DB
- **`kodiSecrets`** — injects Real-Debrid token (from sops-nix) into Umbrella, Seren, and FenLight addon settings; sets skin and GUI defaults

## Secrets

Requires `realdebrid_token` in sops-nix (`modules/common/sops.nix`).

## Integration

`default.nix` is imported by `modules/common/programs/media/default.nix`, which is imported by `modules/common/programs.nix`.
