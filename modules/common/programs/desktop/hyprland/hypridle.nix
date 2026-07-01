{
  config,
  pkgs,
  ...
}: {
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock"; # avoid starting multiple hyprlock instances.
        # Hyprland 0.55+ Lua config evals `hyprctl dispatch <x>` as Lua, so the
        # old `dpms on` string fails with `')' expected near 'on'`. Use the Lua
        # dispatcher form instead.
        after_sleep_cmd = ''hyprctl dispatch 'hl.dsp.dpms("on")' ''; # to avoid having to press a key twice to turn on the display.
      };

      listener = [
        {
          timeout = 5400; # 5.5min
          on-timeout = ''hyprctl dispatch 'hl.dsp.dpms("off")' ''; # screen off when timeout has passed
          on-resume = ''hyprctl dispatch 'hl.dsp.dpms("on")' && brightnessctl -r''; # screen on when activity is detected after timeout has fired.
        }
      ];
    };
  };
}
