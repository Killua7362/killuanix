-- Per-host monitor layout for killua (MSI Claw handheld).
--
-- Replaces services.kanshi. The handheld panel (eDP-1) stays ON at all times,
-- including when docked — docking an external EXTENDS the desktop rather than
-- replacing the internal screen (departs from the old kanshi docked profiles,
-- which disabled eDP).
--
-- eDP-1 is the anchor at `auto`; externals (DP-1 / HDMI-A-1) attach to its LEFT
-- via `auto-left`, so Hyprland reflows the layout on every plug/unplug. Single
-- owner (Hyprland) — no kanshi double-reconfig race (that race crashed every
-- Wayland client with `wl_display: invalid object` on undock).

hl.monitor({output = "eDP-1", mode = "preferred", position = "auto", scale = 1})
hl.monitor({output = "HDMI-A-1", mode = "preferred", position = "auto-left", scale = 1})
hl.monitor({output = "DP-1", mode = "preferred", position = "auto-left", scale = 1})

-- Workspaces 1-6 jump to whatever external connects (port-agnostic). Shared
-- with chrollo — see lua/ws-external.lua.
require("ws-external").setup("eDP-1")
