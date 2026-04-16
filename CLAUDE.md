# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal Nix flake configuration managing three target platforms from a single repo:

- **NixOS** (`nixosConfigurations.killua`) — full NixOS system with Home Manager integrated via the NixOS module
- **Arch Linux** (`homeManagerConfigurations.archnix`) — standalone Home Manager on Arch, uses `nixGL` for GPU wrapping and `aconfmgr` for native package tracking
- **macOS** (`darwinConfigurations.macnix`) — nix-darwin with Home Manager

## Build / Apply Commands

```bash
# NixOS — rebuild full system
sudo nixos-rebuild switch --flake .#killua

# Arch Linux — standalone Home Manager
nix build '.#homeManagerConfigurations.archnix.activationPackage' && ./result/activate
# or, if home-manager CLI is available:
home-manager switch --flake '.#archnix'

# macOS
darwin-rebuild switch --flake .#macnix

# Format all nix files (alejandra)
nix fmt
```

## Architecture

### Flake outputs

| Output | Entry point | Description |
|---|---|---|
| `nixosConfigurations.killua` | `nixos/configuration.nix` | NixOS system config; Home Manager wired in as a NixOS module (`nixos/home-manager/home.nix`) |
| `homeManagerConfigurations.archnix` | `archnix/home.nix` | Standalone HM for Arch Linux |
| `darwinConfigurations.macnix` | `macnix/default.nix` | nix-darwin system + HM |
| `systemConfigs.default` | `archnix/system-manager.nix` | `system-manager` config for Arch (container registry, podman, lingering) |

### Module layers

- **`modules/common/`** — pure data and Home Manager modules shared by all platforms
  - `user.nix` — canonical user config (username, email, SSH keys, session vars) referenced as `inputs.self.commonModules.user.userConfig`
  - `packages.nix` — package sets (`commonPackages`, `terminalPackages`, `desktopPackages`, `devPackages`, `macPackages`) consumed by `cross-platform/default.nix`
  - `programs.nix` — imports all per-program HM modules (kitty, git, hyprland, neovim, firefox, etc.)
  - `sops.nix` — sops-nix secret declarations
- **`modules/cross-platform/default.nix`** — the main Home Manager entrypoint imported by every platform; assembles packages, sops, programs, theming, and platform-conditional logic (`stdenv.isLinux` / `isDarwin`)
- **`modules/common/programs/`** — individual program configs organized by category, each with its own `CLAUDE.md`:
  - [`audio/CLAUDE.md`](modules/common/programs/audio/CLAUDE.md) — PipeWire/WirePlumber tuning, Bluetooth audio, Spotify (spicetify-nix)
  - [`browsers/CLAUDE.md`](modules/common/programs/browsers/CLAUDE.md) — Firefox (Arkenfox + Natsumi), Qutebrowser → [`firefox/CLAUDE.md`](modules/common/programs/browsers/firefox/CLAUDE.md)
  - [`desktop/CLAUDE.md`](modules/common/programs/desktop/CLAUDE.md) — Hyprland, Satty, desktop entries → [`hyprland/CLAUDE.md`](modules/common/programs/desktop/hyprland/CLAUDE.md)
  - [`dev/CLAUDE.md`](modules/common/programs/dev/CLAUDE.md) — Git, Lazygit, Claude Code, OpenCode
  - [`editors/CLAUDE.md`](modules/common/programs/editors/CLAUDE.md) — Neovim (nixCats), Zed → [`neovim/CLAUDE.md`](modules/common/programs/editors/neovim/CLAUDE.md)
  - [`media/kodi/CLAUDE.md`](modules/common/programs/media/kodi/CLAUDE.md) — Kodi media center, Arctic Fuse skin, custom addons, Real-Debrid integration
  - [`openchamber/CLAUDE.md`](modules/common/programs/openchamber/CLAUDE.md) — OpenChamber Web GUI package
  - [`shells/CLAUDE.md`](modules/common/programs/shells/CLAUDE.md) — Zsh, Fish, Starship prompt
  - [`terminal/CLAUDE.md`](modules/common/programs/terminal/CLAUDE.md) — Kitty, Zellij
  - [`utils/CLAUDE.md`](modules/common/programs/utils/CLAUDE.md) — Yazi, Zathura, dotfile symlinks → [`yazi/CLAUDE.md`](modules/common/programs/utils/yazi/CLAUDE.md)
- **`modules/containers/`** — quadlet / portainer container definitions

### Platform-specific directories

- `nixos/` — NixOS system config + hardware config; `nixos/home-manager/home.nix` adds NixOS-only HM modules and packages
- `archnix/` — Arch-specific HM config; wraps Hyprland and Zed with `nixGL`; includes `aconfmgr/` submodule for Arch package tracking
- `macnix/` — Darwin system settings, Homebrew casks (`brew.nix`), macOS-specific packages

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
