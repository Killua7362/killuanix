{
  config,
  pkgs,
  hostName ? null,
  ...
}: let
  # chrollo idle behavior differs from the other hosts: lock on idle but keep
  # the display powered on (no DPMS off). killua/archnix keep the original
  # screen-off-on-idle listener.
  isChrollo = hostName == "chrollo";
in {
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        # Lock via DMS (same locker as the Super+L keybind and DMS's own
        # loginctlLockIntegration), so a loginctl lock-session — e.g. chrollo's
        # HandleLidSwitch=lock on lid close, or the idle listener below — does
        # not race a second ext-session-lock client. Falls back to hyprlock if
        # dms is unavailable.
        lock_cmd = "dms ipc call lock lock || pidof hyprlock || hyprlock";
        # Hyprland 0.55+ Lua config evals `hyprctl dispatch <x>` as Lua, so the
        # old `dpms on` string fails with `')' expected near 'on'`. Use the Lua
        # dispatcher form instead.
        after_sleep_cmd = ''hyprctl dispatch 'hl.dsp.dpms("on")' ''; # to avoid having to press a key twice to turn on the display.
      };

      listener =
        if isChrollo
        then [
          {
            # Lock after 5min idle; screen stays on (no DPMS off by request).
            # loginctl lock-session fires the login1 Lock signal → lock_cmd
            # (DMS), and marks the session locked in logind.
            timeout = 300;
            on-timeout = "loginctl lock-session";
          }
        ]
        else [
          {
            timeout = 5400; # 5.5min
            on-timeout = ''hyprctl dispatch 'hl.dsp.dpms("off")' ''; # screen off when timeout has passed
            on-resume = ''hyprctl dispatch 'hl.dsp.dpms("on")' && brightnessctl -r''; # screen on when activity is detected after timeout has fired.
          }
        ];
    };
  };
}
