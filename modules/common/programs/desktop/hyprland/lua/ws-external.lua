-- Shared helper: move workspaces 1-6 onto a connected external monitor.
--
-- Port-agnostic — works whether the external comes up as HDMI-A-1, DP-1, USB-C
-- DP-alt, etc. A static `hl.workspace_rule{ monitor = … }` can't do this (it
-- binds to one fixed connector name), so the move runs on the `monitor.added`
-- event. Only existing workspaces are moved (no phantom empties created on the
-- external). On unplug Hyprland relocates the external's workspaces back to the
-- internal panel on its own — no handler needed.
--
-- Used by each per-host device-monitors.lua: `require("ws-external").setup("eDP-1")`.

local M = {}

function M.setup(internal)
  internal = internal or "eDP-1"

  local function external_name()
    for _, m in ipairs(hl.get_monitors()) do
      if m.name ~= internal then
        return m.name
      end
    end
    return nil
  end

  local function move_workspaces()
    local ext = external_name()
    if not ext then
      return
    end
    for _, ws in ipairs(hl.get_workspaces()) do
      if ws.id >= 1 and ws.id <= 6 then
        hl.dispatch(hl.dsp.workspace.move({ workspace = tostring(ws.id), monitor = ext }))
      end
    end
  end

  hl.on("monitor.added", move_workspaces)

  -- Cover an external already connected at config load / reload.
  move_workspaces()
end

return M
