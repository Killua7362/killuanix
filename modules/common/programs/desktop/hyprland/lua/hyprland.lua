-- Entry point loaded by Hyprland directly.
--   ~/.config/hypr/hyprland.lua → mkOutOfStoreSymlink → this file
-- Edits here apply via Hyprland autoreload — no nixos-rebuild needed.

local HOME = os.getenv("HOME")
local LUA_DIR = HOME .. "/killuanix/modules/common/programs/desktop/hyprland/lua"

package.path = package.path
  .. ";" .. LUA_DIR .. "/?.lua"
  .. ";" .. HOME .. "/.config/hypr/?.lua"

local function try_require(name)
  if package.searchpath(name, package.path) then
    require(name)
  end
end

require("env")
require("general")
-- Per-host monitor layout (e.g. chrollo's device-monitors.lua). Hyprland owns
-- output hotplug natively here — no kanshi. Set before rules/execs so outputs
-- exist when workspace/window rules evaluate.
try_require("device-monitors")
require("misc")
require("layout")
require("input")
-- Per-host touchpad gestures (chrollo ships device-gestures.lua; killua
-- handheld intentionally has none). Loaded like device-monitors.
try_require("device-gestures")
require("rules")
require("execs")
require("leader")

local kb = require("keybinds")
try_require("device-keybinds")
kb.register()
