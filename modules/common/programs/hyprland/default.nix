{
  pkgs,
  lib,
  inputs,
  config,
  ...
}: {
      imports = [
        ./env.nix
        ./general.nix
        ./misc.nix
        ./windowrules.nix
        ./execs.nix
        ./gestures.nix
        ./layout.nix
        ./input.nix
        ./keybinds.nix
        ./hyprlock.nix
        ./hypridle.nix
        ./dms.nix
      ];

      wayland.windowManager.hyprland = {
        enable = true;
        # set the flake package
        package =(config.lib.nixGL.wrap inputs.hyprland.packages.${inputs.nixpkgs-unstable.legacyPackages.x86_64-linux.stdenv.hostPlatform.system}.hyprland);
        # portalPackage = inputs.hyprland.packages.${ inputs.nixpkgs-unstable.legacyPackages.x86_64-linux.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
        systemd.variables = ["--all"];
        systemd.enable = false; # for uwsm
        xwayland.enable = true;
        plugins = [
            inputs.hyprscroller.packages.${pkgs.stdenv.hostPlatform.system}.hyprscroller
        ];
        settings = {
        "$mod" = "SUPER";
        };
      };

}
