
{ lib,pkgs, ... }: let
once = [
  "dms run"
  # fcitx5
  "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent"
  "wl-paste --type text --watch bash -c 'cliphist store && qs -c $qsConfig ipc call cliphistService update'"
  "wl-paste --type image --watch bash -c 'cliphist store && qs -c $qsConfig ipc call cliphistService update'"
  "nm-applet --indicator"
  "blueman-applet"
  "kdeconnect-indicator"
  "sunshine"
];
always = [

];
in {
  wayland.windowManager.hyprland.settings = {
        exec-once = (map (x: "uwsm app -- ${x}") once) ++ [
          "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
          "hyprpm reload"
        ];
        exec = (map (x: "uwsm app -- ${x}") always) ++ [

        ];
  };
}
