{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {
  imports = [
    ../../modules/cross-platform
    ./users/dots-manage.nix
    inputs.nix-flatpak.homeManagerModules.nix-flatpak
    inputs.dms.homeModules.dankMaterialShell.default
  ];

  # NixOS-specific overlays
  nixpkgs.overlays = [
     inputs.neovim-nightly-overlay.overlays.default
  ];

  # NixOS-specific packages
  home.packages = with pkgs; [
    jetbrains.idea-ultimate
#    inputs.quickshell.packages.x86_64-linux.default
#	fish
    inputs.antigravity-nix.packages.x86_64-linux.default
    #$javaPackages.compiler.openjdk8
    claude-code
    claude-code-router
    #sublime
  ];

  # NixOS-specific systemd configuration
  systemd.user.startServices = "sd-switch";

  # NixOS-specific state version
  home.stateVersion = "25.11";
}
