{ lib, ... }: {
  wayland.windowManager.hyprland.settings = {
      general = {
        col.active_border = "rgba(777777AA)";
        col.inactive_border = "rgba(c6c6c6AA)";
      };
    };
}
