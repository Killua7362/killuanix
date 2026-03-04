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
    inputs.dms.homeModules.dank-material-shell
    inputs.chaotic.homeManagerModules.default
    inputs.vicinae.homeManagerModules.default
    inputs.nixCats.homeModule
    inputs.nix-index-database.homeModules.default
    inputs.quadlet-nix.homeManagerModules.quadlet
    ../../modules/containers/quadlet.nix
  inputs.spicetify-nix.homeManagerModules.default
  ];

  # NixOS-specific overlays
  nixpkgs.overlays = [
     inputs.neovim-nightly-overlay.overlays.default
     inputs.nur.overlays.default
  ];

  # NixOS-specific packages
  home.packages = with pkgs; [
    jetbrains.idea
    jetbrains.webstorm
#    inputs.quickshell.packages.x86_64-linux.default
#	fish
    inputs.antigravity-nix.packages.x86_64-linux.default
    #$javaPackages.compiler.openjdk8
    claude-code
    claude-code-router
    #sublime
  ];


  programs.zed-editor.package = inputs.zed-editor-flake.packages.${pkgs.stdenv.hostPlatform.system}.zed-editor-bin;

    wayland.windowManager.hyprland = {
      package = null;
      portalPackage = null;
    };

  # NixOS-specific systemd configuration
  systemd.user.startServices = "sd-switch";

  # NixOS-specific state version
  home.stateVersion = "25.11";
}
