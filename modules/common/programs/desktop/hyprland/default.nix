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
    systemd.variables = ["--all"];
    systemd.enable = false; # for uwsm
    xwayland.enable = true;
    extraConfig = ''
      source = ~/.config/hypr/monitors.conf
      source = ~/.config/hypr/workspaces.conf

      plugin {
      }
    '';
    plugins = [
    ];
    settings = {
      "$mod" = "SUPER";
    };
  };
}
