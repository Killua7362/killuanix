{
  lib,
  pkgs,
  ...
}: let
  once = [
    "dms run"
    # fcitx5
    "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent"
    "nm-applet --indicator"
    "blueman-applet"
    #"kdeconnect-indicator"
    "sunshine"
  ];
  always = [
  ];
in {
  wayland.windowManager.hyprland.settings = {
    exec-once =
      (map (x: "uwsm app -- ${x}") once)
      ++ [
        "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE"
      ];
    exec =
      (map (x: "uwsm app -- ${x}") always)
      ++ [
      ];
  };
}
