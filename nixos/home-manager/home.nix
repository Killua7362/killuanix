{ inputs, lib, config, pkgs, ... }:

{
  imports = [
    ../../modules/cross-platform
    ./users/dots-manage.nix
    inputs.nix-flatpak.homeManagerModules.nix-flatpak
  ];

  # NixOS-specific overlays
  nixpkgs.overlays = [
    inputs.neovim-nightly-overlay.overlays.default
  ];

  # NixOS-specific packages
  home.packages = with pkgs; [
    jetbrains.idea-ultimate
  ];

  # NixOS-specific systemd configuration
  systemd.user.startServices = "sd-switch";

  # NixOS-specific state version
  home.stateVersion = "25.11";
}
