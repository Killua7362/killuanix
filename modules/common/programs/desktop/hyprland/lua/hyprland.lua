-- Entry point loaded by Hyprland directly.
--   ~/.config/hypr/hyprland.lua → mkOutOfStoreSymlink → this file
-- Edits here apply via Hyprland autoreload — no nixos-rebuild needed.

local HOME = os.getenv("HOME")
local LUA_DIR = HOME .. "/killuanix/modules/common/programs/desktop/hyprland/lua"

package.path = package.path
  .. ";" .. LUA_DIR .. "/?.lua"

local function try_require(name)
  if package.searchpath(name, package.path) then
    require(name)
  end
end

require("env")
require("general")
require("misc")
require("layout")
require("input")
require("gestures")
require("rules")
require("execs")
require("leader")

local kb = require("keybinds")
try_require("device-keybinds")
kb.register()
