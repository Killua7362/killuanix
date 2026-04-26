# Standalone Home Manager root for the macnix host.
#
# Mirrors chrollo/home-manager/home.nix with Linux-only bits removed:
#   - no nix-flatpak / chaotic / DMS / vicinae / hyprland
#   - no NixOS-specific systemd.user wiring
#
# All shared program config (neovim, git, kitty, firefox, audio, shells, …)
# comes through ../../modules/cross-platform, which already gates by
# stdenv.isLinux / isDarwin internally.
{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {
  imports = [
    ../../modules/cross-platform
    ./karabiner.nix
    inputs.sops-nix.homeManagerModules.sops
    inputs.nixCats.homeModule
    inputs.nix-index-database.homeModules.default
    inputs.spicetify-nix.homeManagerModules.default
  ];

  # Standalone Home Manager needs an explicit nix package (under the
  # nix-darwin module integration it was inherited from the system).
  nix.package = pkgs.nix;

  nixpkgs.overlays = [
    inputs.neovim-nightly-overlay.overlays.default
    inputs.nur.overlays.default
    inputs.yazi.overlays.default
    inputs.nix-yazi-flavors.overlays.default
    inputs.claude-code.overlays.default
  ];

  programs.zsh.enable = true;

  home.stateVersion = "24.05";
}
