{ config, pkgs, ... }:{
    services.hypridle = {
      enable = true;
      settings = {
          general = {
              lock_cmd = "pidof hyprlock || hyprlock";       # avoid starting multiple hyprlock instances.
              after_sleep_cmd = "hyprctl dispatch dpms on";  # to avoid having to press a key twice to turn on the display.
          };

          listener =[
            {
                timeout = 5400;                                                     # 5.5min
                on-timeout = "hyprctl dispatch dpms off";                            # screen off when timeout has passed
                on-resume = "hyprctl dispatch dpms on && brightnessctl -r";          # screen on when activity is detected after timeout has fired.
            }
          ];
        };
    };
}
