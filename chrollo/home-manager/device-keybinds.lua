-- Per-host keybinds for chrollo (loaded via try_require("device-keybinds") in
-- lua/hyprland.lua). killua/archnix ship none.
--
-- Power button: logind owns the *short* press (HandlePowerKey=suspend in
-- chrollo/power.nix — DMS locks first via lockBeforeSuspend, so it sleeps
-- locked) and ignores the *long* press. This adds a long-press bind so holding
-- the power button opens the DMS power menu (shutdown / reboot / logout /
-- suspend / lock / restart). The KEY_POWER event still reaches Hyprland because
-- logind only monitors the power button, it does not grab it exclusively — so
-- short tap → logind suspend, long hold → this bind. locked=true lets it work
-- from the lock screen too. (Plain lock without suspend is Super+L.)
hl.bind("XF86PowerOff", hl.dsp.exec_cmd("uwsm-app -- dms ipc call powermenu open"), {
  long_press = true,
  locked = true,
})
