-- Leader-style submaps. Active submap surfaces as a pill in the DMS bar via
-- the LeaderHud quickshell plugin (../qml/leader-hud/). The plugin reads
-- ~/.cache/leader-hud/state (string = active submap name, empty = no submap)
-- and ~/.config/leader-hud/submaps.json (icon + name + key metadata, written
-- declaratively from default.nix).

local STATE = os.getenv("HOME") .. "/.cache/leader-hud/state"

local function enter(name)
  hl.exec_cmd("mkdir -p $HOME/.cache/leader-hud && echo " .. name .. " > " .. STATE)
end

local function clear_state()
  hl.exec_cmd("echo '' > " .. STATE)
end

-- Active submaps. Add more by extending this list.
local submaps = {
  {
    name = "leader",
    trigger = "SUPER, Space",
    slots = {
      { key = "F", cmd = "uwsm-app -- nemo" },
      { key = "B", cmd = "uwsm-app -- firefox" },
      { key = "T", cmd = "uwsm-app -- ghostty" },
      { key = "E", cmd = "uwsm-app -- zeditor" },
      { key = "M", cmd = "uwsm-app -- thunderbird" },
      { key = "O", cmd = "uwsm-app -- obsidian" },
    },
  },
}

-- Keys swallowed inside a submap so the focused window never receives them.
local swallow_keys = {
  "a","b","c","d","e","f","g","h","i","j","k","l","m",
  "n","o","p","q","r","s","t","u","v","w","x","y","z",
  "0","1","2","3","4","5","6","7","8","9",
  "minus","equal","bracketleft","bracketright","backslash",
  "semicolon","apostrophe","grave","comma","period","slash",
  "Tab","space",
}

local function set_has(set, k)
  for _, v in ipairs(set) do if v == k then return true end end
  return false
end

-- hl.bind expects "MOD+MOD+KEY" — never the legacy "MOD, KEY" hyprlang form.
local normalize = require("keybinds").normalize

for _, sub in ipairs(submaps) do
  -- Trigger bind: write state then enter submap.
  hl.bind(normalize(sub.trigger), function()
    enter(sub.name)
    hl.dispatch(hl.dsp.submap(sub.name))
  end)

  hl.define_submap(sub.name, function()
    -- Slot binds: run command, clear state, reset submap.
    local slot_keys = {}
    for _, slot in ipairs(sub.slots) do
      table.insert(slot_keys, string.lower(slot.key))
      hl.bind(slot.key, function()
        clear_state()
        hl.exec_cmd(slot.cmd)
        hl.dispatch(hl.dsp.submap("reset"))
      end)
    end

    -- No-op swallow for every unbound key.
    for _, k in ipairs(swallow_keys) do
      if not set_has(slot_keys, k) then
        hl.bind(k, hl.dsp.exec_cmd("true"))
      end
    end

    -- Escape / Return: clear and exit.
    local function cancel()
      clear_state()
      hl.dispatch(hl.dsp.submap("reset"))
    end
    hl.bind("Escape", cancel)
    hl.bind("Return", cancel)
  end)
end
