# Home Manager configuration for handheld
# Reuses cross-platform modules (neovim, kitty, git, firefox, audio, shells, etc.)
{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {
  imports = [
    ../modules/cross-platform
    inputs.nixCats.homeModule
    inputs.nix-index-database.homeModules.default
    inputs.spicetify-nix.homeManagerModules.default
  ];

  # NixOS-specific overlays (matching killua home.nix)
  nixpkgs.overlays = [
    inputs.neovim-nightly-overlay.overlays.default
    inputs.nur.overlays.default
    inputs.yazi.overlays.default
    inputs.nix-yazi-flavors.overlays.default
  ];

  # Handheld-specific packages (most gaming packages are at system level)
  home.packages = with pkgs; [
    inputs.antigravity-nix.packages.x86_64-linux.default
  ];

  # Hyprland not used on handheld (Plasma + Game Mode instead)
  wayland.windowManager.hyprland.enable = lib.mkForce false;

  # NixOS-specific systemd configuration
  systemd.user.startServices = "sd-switch";

  home.stateVersion = "25.11";
}
