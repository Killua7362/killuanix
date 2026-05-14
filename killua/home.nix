# Home Manager configuration for the killua host (MSI Claw handheld).
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
    ../modules/common/programs/notes
    ../modules/vms
    ./kanshi.nix
    inputs.sops-nix.homeManagerModules.sops
    inputs.nix-flatpak.homeManagerModules.nix-flatpak
    inputs.dms.homeModules.dank-material-shell
    inputs.chaotic.homeManagerModules.default
    inputs.vicinae.homeManagerModules.default
    inputs.nixCats.homeModule
    inputs.nix-index-database.homeModules.default
    inputs.spicetify-nix.homeManagerModules.default
  ];

  # Standalone Home Manager needs an explicit nix package (under the NixOS
  # module it was inherited from the system).
  nix.package = pkgs.nix;

  # Lunar Lake BT controller can't open an mSBC SCO transport ("failed to
  # get HFP codec 2"), which leaves HFP unregistered and breaks the BT mic
  # in Meet/Discord. With mSBC off, HFP falls back to CVSD (8 kHz) and the
  # profile activates cleanly. Other hosts keep the default (true).
  audio.bluetooth.enableMsbc = false;

  # NixOS-specific overlays (matching chrollo home.nix)
  nixpkgs.overlays = [
    inputs.neovim-nightly-overlay.overlays.default
    inputs.nur.overlays.default
    inputs.yazi.overlays.default
    inputs.nix-yazi-flavors.overlays.default
    inputs.claude-code.overlays.default
    inputs.nixpille-obsidian-community-plugins.overlays.default
  ];

  # Handheld-specific packages (most gaming packages are at system level)
  home.packages = with pkgs; [
    inputs.antigravity-nix.packages.x86_64-linux.default
    jetbrains.idea
    jetbrains.webstorm
    antimicrox
    # Ships org.kde.ksshaskpass.desktop into XDG_DATA_DIRS so xdg-desktop-portal
    # can resolve the app id when SSH_ASKPASS=ksshaskpass is invoked under Qt.
    kdePackages.ksshaskpass
  ];

  # antimicrox desktop controller profile
  # xdg.configFile."antimicrox/desktopcontroller.amgp".source = ../DotFiles/archnix/antimicrox.desktopcontroller.amgp;
  #
  # # Autostart antimicrox in Hyprland with desktop controller profile
  # wayland.windowManager.hyprland.settings.exec-once = [
  #   "uwsm app -- antimicrox --tray --hidden --profile desktopcontroller"
  # ];

  programs.zed-editor.package = inputs.zed-editor-flake.packages.${pkgs.stdenv.hostPlatform.system}.zed-editor-bin;

  wayland.windowManager.hyprland = {
    package = null;
    portalPackage = null;
  };

  # NixOS-specific systemd configuration
  systemd.user.startServices = "sd-switch";

  home.stateVersion = "25.11";
}
