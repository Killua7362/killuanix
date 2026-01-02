{ lib, ... }: {
  wayland.windowManager.hyprland.settings = {
      misc = {
          disable_hyprland_logo = true;
          disable_splash_rendering = true;
          background_color = "rgba(131313FF)";
      };
  };
}
