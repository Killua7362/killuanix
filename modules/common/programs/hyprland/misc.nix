{ lib, ... }: {
  wayland.windowManager.hyprland.settings = {
      misc = {
          background_color = "rgba(131313FF)";
          disable_hyprland_logo = true;
          disable_splash_rendering = true;
          vfr = 1;
          vrr = 1;
          mouse_move_enables_dpms = true;
          key_press_enables_dpms = true;
          animate_manual_resizes = false;
          animate_mouse_windowdragging = false;
          enable_swallow = false;
          swallow_regex = "(foot|kitty|allacritty|Alacritty)";
          # new_window_takes_over_fullscreen = 2;
          allow_session_lock_restore = true;
          session_lock_xray = true;
          initial_workspace_tracking = false;
          focus_on_activate = true;
          force_default_wallpaper = -1;
      };
      animations = {
        enabled = true;
          animation = [
              "windows, 0"
              "windowsIn, 0"
              "windowsOut, 0"
              "windowsMove, 0"
              "workspaces, 0"
              "fade, 0"
          ];
      };
      plugin = {
          scroller = {
                column_widths = "onehalf one";
            };
        };
  };
}
