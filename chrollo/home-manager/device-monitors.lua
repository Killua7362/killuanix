-- Per-host monitor layout for chrollo (ThinkPad, Iris Xe / i915).
--
-- Replaces services.kanshi (removed). Hyprland owns output hotplug natively,
-- which removes the kanshi-vs-Hyprland double-reconfig race. That race was
-- corrupting the Wayland object registry on undock: every client holding a
-- surface on the dropped output got `wl_display: error 0: invalid object` and
-- died together (chrome SIGTRAP, ghostty, xdg-desktop-portal-hyprland SEGV,
-- kdeconnect, vicinae, kwallet). Triggered whenever the external monitor lost
-- power while charging.
--
-- eDP-1 is the anchor; externals attach to its LEFT (matches the old kanshi
-- profiles: external at 0,0, laptop to the right). `auto`/`auto-left` make
-- Hyprland reflow the layout on every plug/unplug — that IS the docked/undocked
-- behavior, now handled in-compositor with a single owner.
--
-- Verify port names while docked: `hyprctl monitors all`. If the external comes
-- up as a different connector, add/rename a line below.

hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 1.25 })
hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "auto-left", scale = 1 })
hl.monitor({ output = "DP-1", mode = "preferred", position = "auto-left", scale = 1 })

-- Workspaces 1-6 jump to whatever external connects (port-agnostic). Shared
-- with killua — see lua/ws-external.lua.
require("ws-external").setup("eDP-1")
