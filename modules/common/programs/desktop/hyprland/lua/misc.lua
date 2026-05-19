-- Misc, xwayland, plugin, animations. Ported from misc.nix.
-- Animations are all disabled (durations 0) — `hl.animation` calls below
-- replace the legacy `animations.animation` string list.

hl.config({
  xwayland = {
    force_zero_scaling = true,
  },
  misc = {
    background_color = "rgba(131313FF)",
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    mouse_move_enables_dpms = true,
    key_press_enables_dpms = true,
    animate_manual_resizes = false,
    animate_mouse_windowdragging = false,
    enable_swallow = false,
    swallow_regex = "(foot|kitty|ghostty|allacritty|Alacritty)",
    allow_session_lock_restore = true,
    session_lock_xray = true,
    initial_workspace_tracking = false,
    focus_on_activate = true,
    force_default_wallpaper = -1,
  },
  animations = {
    enabled = true,
  },
  plugin = {
    scroller = {
      column_widths = "onehalf one",
    },
  },
})

-- All animations disabled (speed 0 equivalent in 0.55+: enabled=false).
hl.animation({ leaf = "windows",      enabled = false })
hl.animation({ leaf = "windowsIn",    enabled = false })
hl.animation({ leaf = "windowsOut",   enabled = false })
hl.animation({ leaf = "windowsMove",  enabled = false })
hl.animation({ leaf = "workspaces",   enabled = false })
hl.animation({ leaf = "fade",         enabled = false })
