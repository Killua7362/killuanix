# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal Nix flake configuration managing multiple target platforms from a single repo:

- **NixOS desktop** (`nixosConfigurations.chrollo` + standalone `homeManagerConfigurations.chrollo`) — system and Home Manager are **separate switches** (NixOS module integration was removed; run `nixos-rebuild` and `home-manager` independently)
- **NixOS handheld** (`nixosConfigurations.killua` + standalone `homeManagerConfigurations.killua`) — MSI Claw / handheld variant on Jovian-NixOS + CachyOS kernel; same split system/HM setup as chrollo
- **Arch Linux** (`homeManagerConfigurations.archnix`) — standalone Home Manager on Arch, uses `nixGL` for GPU wrapping and `aconfmgr` for native package tracking
- **macOS** (`darwinConfigurations.macnix`) — nix-darwin with Home Manager wired in via the Darwin module (unified switch)

## Build / Apply Commands

```bash
# NixOS desktop (chrollo) — system and home are separate switches
sudo nixos-rebuild switch --flake .#chrollo
home-manager switch --flake .#chrollo

# NixOS handheld (killua, MSI Claw)
sudo nixos-rebuild switch --flake .#killua
home-manager switch --flake .#killua

# Arch Linux — standalone Home Manager
nix build '.#homeManagerConfigurations.archnix.activationPackage' && ./result/activate
# or, if home-manager CLI is available:
home-manager switch --flake '.#archnix'

# macOS
darwin-rebuild switch --flake .#macnix

# Format all nix files (alejandra)
nix fmt
```

## Post-install setup

The flake auto-bootstraps most services, but a few one-shot manual steps remain after a fresh NixOS install:

- **Linkding** (`modules/containers/linkding.nix`) — admin user (`admin`) is auto-created from the sops-encrypted `linkding_admin_password`, and the sops-encrypted `secrets/linkding-bookmarks.html` is imported once per fresh data volume by `linkding-import.service`. Just open http://localhost:9090, log in with the password from `sops decrypt secrets/personal.yaml`, and grab an API token from Settings → Integrations for the browser extension.

## Architecture

### Flake outputs

| Output | Entry point | Description |
|---|---|---|
| `nixosConfigurations.chrollo` | `chrollo/configuration.nix` | Desktop NixOS system config (system-only; HM lives in `homeManagerConfigurations.chrollo`) |
| `nixosConfigurations.killua` | `killua/configuration.nix` | Handheld/MSI Claw NixOS variant (Jovian + CachyOS kernel); system-only |
| `homeManagerConfigurations.chrollo` | `chrollo/home-manager/home.nix` | Standalone HM for the chrollo host |
| `homeManagerConfigurations.killua` | `killua/home.nix` | Standalone HM for the killua host |
| `homeManagerConfigurations.archnix` | `archnix/home.nix` | Standalone HM for Arch Linux |
| `darwinConfigurations.macnix` | `macnix/default.nix` | nix-darwin system + HM |
| `systemConfigs.default` | `archnix/system-manager.nix` | `system-manager` config for Arch (container registry, podman, lingering) |

### Module layers

- **`modules/common/`** — pure data and Home Manager modules shared by all platforms
  - `user.nix` — canonical user config (username, email, SSH keys, session vars) referenced as `inputs.self.commonModules.user.userConfig`
  - `packages.nix` — package sets (`commonPackages`, `terminalPackages`, `desktopPackages`, `devPackages`, `macPackages`) consumed by `cross-platform/default.nix`
  - `programs.nix` — imports all per-program HM modules (kitty, git, hyprland, neovim, firefox, etc.)
  - `mcp-servers.nix` — declarative MCP server catalog (shared by Claude / OpenCode configs via `mcp-servers-nix`)
  - `sops.nix` / `sops-system.nix` — sops-nix secret declarations (HM and NixOS-system scopes)
- **`modules/cross-platform/default.nix`** — the main Home Manager entrypoint imported by every platform; assembles packages, sops, programs, theming, and platform-conditional logic (`stdenv.isLinux` / `isDarwin`)
- **`modules/common/programs/`** — individual program configs organized by category, each with its own `CLAUDE.md`:
  - [`audio/CLAUDE.md`](modules/common/programs/audio/CLAUDE.md) — PipeWire/WirePlumber tuning, Bluetooth audio, Spotify (spicetify-nix)
  - [`browsers/CLAUDE.md`](modules/common/programs/browsers/CLAUDE.md) — Firefox (Arkenfox + Natsumi), Qutebrowser → [`firefox/CLAUDE.md`](modules/common/programs/browsers/firefox/CLAUDE.md)
  - [`desktop/CLAUDE.md`](modules/common/programs/desktop/CLAUDE.md) — Hyprland, Satty, desktop entries → [`hyprland/CLAUDE.md`](modules/common/programs/desktop/hyprland/CLAUDE.md)
  - [`dev/CLAUDE.md`](modules/common/programs/dev/CLAUDE.md) — Git, Lazygit, Claude Code (+ bundled skills), OpenCode, code-index, jupyter-env MCP
  - [`diagrams/CLAUDE.md`](modules/common/programs/diagrams/CLAUDE.md) — Excalidraw / Mermaid Live launchers, mermaid-cli, `text/vnd.mermaid` MIME wiring
  - [`editors/CLAUDE.md`](modules/common/programs/editors/CLAUDE.md) — Neovim (nixCats), Zed → [`neovim/CLAUDE.md`](modules/common/programs/editors/neovim/CLAUDE.md)
  - [`mail/CLAUDE.md`](modules/common/programs/mail/CLAUDE.md) — Thunderbird with a manually-packaged add-on bundle
  - [`media/kodi/CLAUDE.md`](modules/common/programs/media/kodi/CLAUDE.md) — Kodi media center, Arctic Fuse skin, custom addons, Real-Debrid integration
  - [`notes/CLAUDE.md`](modules/common/programs/notes/CLAUDE.md) — Obsidian vault config (NixOS-only: chrollo + killua)
  - [`openchamber/CLAUDE.md`](modules/common/programs/openchamber/CLAUDE.md) — OpenChamber Web GUI package
  - [`shells/CLAUDE.md`](modules/common/programs/shells/CLAUDE.md) — Zsh, Fish, Starship prompt
  - [`terminal/CLAUDE.md`](modules/common/programs/terminal/CLAUDE.md) — Ghostty (primary under Hyprland), Kitty, Zellij
  - [`theming/CLAUDE.md`](modules/common/programs/theming/CLAUDE.md) — Shared `config.theme.palette`, GTK/libadwaita CSS, Kvantum + qt5ct/qt6ct
  - [`utils/CLAUDE.md`](modules/common/programs/utils/CLAUDE.md) — Yazi, Zathura, Nemo, mimeapps, clipboard-menu, dotfile symlinks → [`yazi/CLAUDE.md`](modules/common/programs/utils/yazi/CLAUDE.md)
- **`modules/containers/`** — quadlet / portainer container definitions (litellm, mcphub, qdrant, searxng, portainer, homepage, excalidraw, mermaid-live, linkding, icloud-drive)
- **`modules/vms/`** — libvirt/qemu VM definitions and plugins (activity-sim, work-vm, vm-manager)
- **`modules/nixos/`**, **`modules/home-manager/`** — thin module entry points re-exported via the flake's `nixosModules` / `homeManagerModules`

### Platform-specific directories

- `chrollo/` — desktop NixOS system config + hardware config; `chrollo/home-manager/home.nix` adds NixOS-only HM modules and packages
- `killua/` — MSI Claw / handheld NixOS config (boot, gaming, hhd, intel-gpu, wifi-fix, handheld-tweaks) with its own `home.nix`
- `archnix/` — Arch-specific HM config; wraps Hyprland and Zed with `nixGL`; includes `aconfmgr/` submodule for Arch package tracking, plus `packages/` and `users/` subdirs
- `macnix/` — Darwin system settings, Homebrew casks (`brew.nix`), macOS-specific packages
- `overlays/`, `packages/` — custom nixpkgs overlays and standalone derivations consumed via `self.customOverlays` / direct imports
- `scripts/`, `sdethings/`, `Notes/` — ad-hoc scripts and notes

### Secrets

Managed with **sops-nix** + **age** encryption. Keys defined in `.sops.yaml`; encrypted secrets live in `secrets/personal.yaml`. The age key file is expected at `~/.config/sops/age/keys.txt`.

### Submodules

- `DotFiles/` — raw dotfiles (firefox configs, quickshell, scripts, etc.) symlinked into place by `dots.nix` and platform-specific `dots-manage.nix`
- `archnix/aconfmgr/` — aconfmgr configuration for Arch native package tracking

## Key Conventions

- The formatter is **alejandra** (`nix fmt`). Run it before committing nix changes.
- User identity and shared session variables are centralized in `modules/common/user.nix` — do not hardcode username/email elsewhere.
- Package lists in `modules/common/packages.nix` are split by category and combined in `cross-platform/default.nix` with platform guards.
- The `DotFiles` submodule is referenced via `${config.home.homeDirectory}/killuanix/DotFiles` for symlinking.

## CLAUDE.md maintenance policy

Every documented directory under `modules/common/programs/` (and the repo root) ships a `CLAUDE.md` that describes its files, notable settings, and integration points. These files must stay in sync with the code — when they drift, future sessions get misled.

**When editing `.nix` files in this repo, you must:**

1. **Update the nearest `CLAUDE.md`** if the change adds/removes/renames a file, changes a documented option or keybinding, changes platform gating (`isLinux`/`isDarwin`/`mkIf`), changes imports, or alters behavior described in the doc. Don't restate implementation details that are obvious from the code — keep the doc focused on *what the module does*, *why it's wired that way*, and *the non-obvious gotchas*.
2. **Create a new `CLAUDE.md`** when you add a new subdirectory under `modules/common/programs/` (or any other place where siblings already have one). Match the style of adjacent docs: H1 title, short overview, `## Files` table, detail sections for notable behavior, closing `## Integration` section naming the import path up to `modules/cross-platform/default.nix` (or the chrollo/killua/archnix/macnix entry point if it's not cross-platform).
3. **Update this root `CLAUDE.md`** — the "individual program configs" list above — whenever you add or remove a module-level `CLAUDE.md`, so the index stays complete.
4. **Do not create `CLAUDE.md` files for directories that don't warrant them** (single-file modules whose source is self-explanatory, or purely-data directories like `templates/`). Prefer extending a parent `CLAUDE.md` with a short subsection.

The goal is that a future Claude Code session can orient itself from the docs alone without re-reading every `.nix` file. If after a change the `CLAUDE.md` in that directory would still be accurate, no update is needed — but verify, don't assume.
