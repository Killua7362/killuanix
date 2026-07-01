{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {
  imports = [
    ../../modules/cross-platform
    ../../modules/common/programs/notes
    ../../modules/common/programs/chat
    ../../modules/common/programs/cloud/azure-bastion
    ./users/dots-manage.nix
    inputs.sops-nix.homeManagerModules.sops
    inputs.nix-flatpak.homeManagerModules.nix-flatpak
    inputs.dms.homeModules.dank-material-shell
    inputs.dms-plugin-registry.homeModules.default
    inputs.chaotic.homeManagerModules.default
    inputs.vicinae.homeManagerModules.default
    inputs.nixCats.homeModule
    inputs.nix-index-database.homeModules.default
    ../../modules/vms
    inputs.spicetify-nix.homeManagerModules.default
  ];

  # Standalone Home Manager needs an explicit nix package (under the NixOS
  # module it was inherited from the system).
  nix.package = pkgs.nix;

  # NixOS-specific overlays
  nixpkgs.overlays = [
    inputs.neovim-nightly-overlay.overlays.default
    inputs.nur.overlays.default
    inputs.yazi.overlays.default
    inputs.nix-yazi-flavors.overlays.default
    inputs.claude-code.overlays.default
    inputs.nixpille-obsidian-community-plugins.overlays.default
  ];

  # NixOS-specific packages
  home.packages = with pkgs; [
    jetbrains.idea
    jetbrains.webstorm
    #    inputs.quickshell.packages.x86_64-linux.default
    #	fish
    inputs.antigravity-nix.packages.x86_64-linux.default
    #$javaPackages.compiler.openjdk8
    #sublime
  ];

  programs.zed-editor.package = inputs.zed-editor-flake.packages.${pkgs.stdenv.hostPlatform.system}.zed-editor-bin;

  wayland.windowManager.hyprland = {
    package = null;
    portalPackage = null;
  };

  # Per-host monitor layout (replaces services.kanshi). Live-edit symlink like
  # hyprland.lua — Hyprland sources it via try_require("device-monitors") and
  # applies output hotplug natively, which fixes the kanshi double-reconfig that
  # crashed every Wayland client on undock.
  xdg.configFile."hypr/device-monitors.lua".source =
    config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/killuanix/chrollo/home-manager/device-monitors.lua";

  # chrollo only hosts the Oracle 19c VM; skip the work-ubuntu Hubstaff VM
  # (avoids the ~3 GB Ubuntu ISO fetch + autoinstall ISO repack).
  vms.workUbuntu.enable = false;

  # NixOS-specific systemd configuration
  systemd.user.startServices = "sd-switch";

  # NixOS-specific state version
  home.stateVersion = "25.11";
}
