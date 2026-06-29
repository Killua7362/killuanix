-- Startup commands. Ported from execs.nix.
-- `uwsm app --` wrapper places each child in its own app-graphical.slice scope
-- with a fresh NOTIFY_SOCKET so they don't hijack the compositor (uwsm#67).

hl.on("hyprland.start", function()
  hl.exec_cmd("uwsm app -- dms run")
  hl.exec_cmd("uwsm app -- hyprpolkitagent")
  hl.exec_cmd("uwsm app -- nm-applet --indicator")
  hl.exec_cmd("uwsm app -- blueman-applet")
  -- sunshine autostart disabled; start manually (`sunshine`) or `systemctl start sunshine` when needed
  hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE")
end)
