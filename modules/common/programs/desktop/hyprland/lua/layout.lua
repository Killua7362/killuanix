-- Layout engines + decoration + cursor + binds. Ported from layout.nix.

hl.config({
  dwindle = {
    preserve_split = true,
    smart_split = false,
    smart_resizing = false,
  },

  decoration = {
    rounding = 8,
    active_opacity = 1.0,
    inactive_opacity = 1.0,
    shadow = {
      enabled = true,
      range = 30,
      render_power = 5,
      offset = "0 5",
      color = "rgba(00000070)",
    },
    blur = {
      enabled = true,
      size = 6,
      passes = 4,
      brightness = 0.5,
      vibrancy = 0.5,
      vibrancy_darkness = 0.5,
    },
  },

  binds = {
    scroll_event_delay = 0,
    hide_special_on_workspace_change = true,
  },

  cursor = {
    zoom_factor = 1,
    zoom_rigid = false,
    hotspot_padding = 1,
  },

  master = {
    new_status = "master",
  },

  scrolling = {
    explicit_column_widths = "1.0, 0.5",
    column_width = 1.0,
    fullscreen_on_one_column = true,
    follow_focus = true,
  },
})
