{
  lib,
  ...
}: {
    wayland.windowManager.hyprland.settings = {
        dwindle = {
           preserve_split = true;
            smart_split = false;
            smart_resizing = false;
            pseudotile = true; # Master switch for pseudotiling. Enabling is bound to mainMod + P in the keybinds section below
        };
        decoration = {
            rounding = 8;
            active_opacity = 1.0;
            inactive_opacity = 1.0;
            shadow.enabled = true;
            shadow.range = 30;
            shadow.render_power = 5;
            shadow.offset = "0 5";
            shadow.color = "rgba(00000070)";
            blur.enabled = true;
            blur.size = 6;
            blur.passes = 4;
            blur.brightness = 0.5;
            blur.vibrancy = 0.5;
            blur.vibrancy_darkness = 0.5;
        };
        binds = {
            scroll_event_delay = 0;
            hide_special_on_workspace_change = true;
        };
        cursor={
            zoom_factor = 1;
            zoom_rigid = false;
            hotspot_padding = 1;
        };
        master = {
            new_status = "master";
        };
    };
}
