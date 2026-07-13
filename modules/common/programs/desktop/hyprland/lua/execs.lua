-- Startup commands. Ported from execs.nix.
-- `uwsm app --` wrapper places each child in its own app-graphical.slice scope
-- with a fresh NOTIFY_SOCKET so they don't hijack the compositor (uwsm#67).

hl.on("hyprland.start", function()
  -- dms is launched as a systemd user service (programs.dank-material-shell.systemd.enable
  -- in dms/default.nix), not here — the service auto-restarts after a Wayland desync.
  -- Do not re-add `uwsm app -- dms run`: that would double-launch it.
  hl.exec_cmd("uwsm app -- hyprpolkitagent")
  hl.exec_cmd("uwsm app -- nm-applet --indicator")
  hl.exec_cmd("uwsm app -- blueman-applet")
  -- sunshine autostart disabled; start manually (`sunshine`) or `systemctl start sunshine` when needed
  hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE")
end)
