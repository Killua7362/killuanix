{ lib, ... }: {

  wayland.windowManager.hyprland.settings = {
    windowrulev2 = [
      "bordercolor rgba(006591AA) rgba(00659177),pinned:1"
    ];
  };
}
