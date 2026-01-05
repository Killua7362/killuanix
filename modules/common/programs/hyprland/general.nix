{ lib, ... }: {
  wayland.windowManager.hyprland.settings = {
      general = {
        col.active_border = "rgba(777777AA)";
        col.inactive_border = "rgba(c6c6c6AA)";
        gaps_in = 5;
        gaps_out = 10;
        border_size = 1;
        layout = "scroller";
        gaps_workspaces = 50;
        resize_on_border = true;
        no_focus_fallback = true;
        allow_tearing = true;
        snap.enabled = true;
        snap.window_gap = 4;
        snap.monitor_gap = 5;
        snap.respect_gaps = true;
      };
    };
}
