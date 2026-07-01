-- Keybinds. Ported from keybinds.nix.
--
-- Bind data is a flat list. M.register() walks it and calls hl.bind.
-- Action helpers below build dispatcher tables; the actual hl.dsp.* call is
-- lazy so the module also loads in plain lua (e.g. for a menu walker).
--
-- Bind option mapping (HL.BindOptions):
--   bind   → no flags
--   bindd  → { description = ... }
--   bindl  → { locked = true }
--   bindel → { repeating = true }   (locked from hyprlang `e` = repeat)
--   bindle → { repeating = true, locked = true }
--   bindld → { locked = true, description = ... }
--   bindm  → mouse bind; { drag = true } where applicable
--   binde  → { repeating = true }

local M = {}

-- Fallback for dispatchers without an obvious lua API. Cheap on modern
-- Hyprland (IPC is in-process), and unambiguous to read against the old conf.
local function hctl(cmd)
  return hl.dsp.exec_cmd("hyprctl dispatch " .. cmd)
end

local A = {}

A.exec     = function(c) return hl.dsp.exec_cmd(c) end
A.global   = function(n) return hl.dsp.global(n) end

A.focus_dir   = function(d) return hl.dsp.focus({ direction = d }) end
A.swap_dir    = function(d) return hl.dsp.window.swap({ direction = d }) end
A.kill        = function()  return hl.dsp.window.close() end
A.toggle_float = function() return hl.dsp.window.float() end
A.pin         = function()  return hl.dsp.window.pin() end
A.drag        = function()  return hl.dsp.window.drag() end
A.mresize     = function()  return hl.dsp.window.resize() end
A.fullscreen  = function(mode)
  if mode == nil then return hl.dsp.window.fullscreen() end
  return hl.dsp.window.fullscreen({ mode = mode })
end
A.resize_exact = function(w, h)
  return hl.dsp.window.resize({ x = w, y = h, relative = false })
end

A.focus_ws    = function(n) return hl.dsp.focus({ workspace = n }) end
A.move_ws     = function(n) return hl.dsp.window.move({ workspace = n }) end
A.move_ws_silent = function(n) return hl.dsp.window.move({ workspace = n, follow = false }) end
A.toggle_special = function(name)
  if name == nil then return hl.dsp.workspace.toggle_special() end
  return hl.dsp.workspace.toggle_special(name)
end

A.layout = function(msg) return hl.dsp.layout(msg) end

-- Dispatchers that are rare or have ambiguous lua signatures: defer to hyprctl.
A.cycle_next         = function() return hctl("cyclenext") end
A.cycle_prev         = function() return hctl("cyclenext prev") end
A.bring_to_top       = function() return hctl("bringactivetotop") end
A.hyprctl_kill       = function() return A.exec("uwsm-app -- hyprctl kill") end
A.fullscreen_state   = function(args) return hctl("fullscreenstate " .. args) end

-- Scroller column-width toggle. Upvalue replaces the old state file in
-- $XDG_RUNTIME_DIR. Alternates direction each press.
local colwidth_dir = "+"
A.toggle_col_width = function()
  return { fn = function()
    colwidth_dir = (colwidth_dir == "+") and "-" or "+"
    hl.dispatch(hl.dsp.layout("colresize " .. colwidth_dir .. "conf"))
  end }
end

M.binds = {
  -- ============================================================
  -- bindd (described binds → flags.description)
  -- ============================================================
  { keys = "Super, Period",                  desc = "Emoji >> clipboard",     bindd = true, action = A.global("quickshell:overviewEmojiToggle") },
  { keys = "Super, A",                       desc = "Toggle left sidebar",    bindd = true, action = A.global("quickshell:sidebarLeftToggle") },
  { keys = "Super, Slash",                   desc = "Toggle cheatsheet",      bindd = true, action = A.global("quickshell:cheatsheetToggle") },
  { keys = "Super, M",                       desc = "Toggle media controls",  bindd = true, action = A.global("quickshell:mediaControlsToggle") },
  { keys = "Ctrl+Alt, Delete",               desc = "Toggle session menu",    bindd = true, action = A.global("quickshell:sessionToggle") },
  { keys = "Super, J",                       desc = "Toggle bar",             bindd = true, action = A.global("quickshell:barToggle") },
  { keys = "Ctrl+Super, T",                  desc = "Toggle wallpaper picker",bindd = true, action = A.global("quickshell:wallpaperSelectorToggle") },
  { keys = "Super+Shift, T",                 desc = "Character recognition",  bindd = true, action = A.exec("uwsm-app --grim -g \"$(slurp $SLURP_ARGS)\" 'tmp.png' && tesseract 'tmp.png' - | wl-copy && rm 'tmp.png'") },
  { keys = "Super, L",                       desc = "Lock",                   bindd = true, action = A.exec("uwsm-app -- dms ipc call lock lock") },
  { keys = "Ctrl+Shift+Alt+Super, Delete",   desc = "Shutdown",               bindd = true, action = A.exec("uwsm-app -- systemctl poweroff || loginctl poweroff") },

  -- ============================================================
  -- bind — sidebar + screenshots
  -- ============================================================
  { keys = "Super+Alt, A",   action = A.global("quickshell:sidebarLeftToggleDetach") },
  { keys = "Super, B",       action = A.global("quickshell:sidebarLeftToggle") },
  { keys = "Super+Shift, R",  action = A.exec("killall ags agsv1 gjs ydotool qs quickshell; dms restart &") },
  { keys = ", Print",        action = A.exec("sh -c 'REGION=$(slurp) || exit; grim -g \"$REGION\" - | satty -f -'") },

  -- ============================================================
  -- Window focus / move (arrow keys + bracket)
  -- ============================================================
  { keys = "Super, Left",       action = A.focus_dir("l") },
  { keys = "Super, Right",      action = A.focus_dir("r") },
  { keys = "Super, Up",         action = A.focus_dir("u") },
  { keys = "Super, Down",       action = A.focus_dir("d") },
  { keys = "Super, BracketLeft",  action = A.focus_dir("l") },
  { keys = "Super, BracketRight", action = A.focus_dir("r") },
  { keys = "Super+Shift, Left",   action = A.swap_dir("l") },
  { keys = "Super+Shift, Right",  action = A.swap_dir("r") },
  { keys = "Super+Shift, Up",     action = A.swap_dir("u") },
  { keys = "Super+Shift, Down",   action = A.swap_dir("d") },

  -- ============================================================
  -- Kill / float / fullscreen / pin
  -- ============================================================
  { keys = "Alt, F4",                       action = A.kill() },
  { keys = "Super, Q",                      action = A.kill() },
  { keys = "Super Shift, C",                action = A.kill() },
  { keys = "Super+Shift+Alt, Q",            action = A.hyprctl_kill() },
  { keys = "Super+Alt, Space",              action = A.toggle_float() },
  { keys = "Super+Shift, F",                action = A.fullscreen() },         -- fullscreen, 0 = real
  { keys = "Super, F",                      action = A.fullscreen("maximized") }, -- fullscreen, 1 = maximized
  { keys = "Super+Alt, F",                  action = A.fullscreen_state("0 3") },
  { keys = "Super, P",                      action = A.pin() },
  { keys = "Super , T",                     action = A.toggle_float() },

  -- ============================================================
  -- Move-to-workspace (scroll, page, arrows)
  -- ============================================================
  { keys = "Super+Shift, mouse_down",        action = A.move_ws("r-1") },
  { keys = "Super+Shift, mouse_up",          action = A.move_ws("r+1") },
  { keys = "Super+Alt, mouse_down",          action = A.move_ws("-1") },
  { keys = "Super+Alt, mouse_up",            action = A.move_ws("+1") },
  { keys = "Super+Alt, Page_Down",           action = A.move_ws("+1") },
  { keys = "Super+Alt, Page_Up",             action = A.move_ws("-1") },
  { keys = "Super+Shift, Page_Down",         action = A.move_ws("r+1") },
  { keys = "Super+Shift, Page_Up",           action = A.move_ws("r-1") },
  { keys = "Ctrl+Super+Shift, Right",        action = A.move_ws("r+1") },
  { keys = "Ctrl+Super+Shift, Left",         action = A.move_ws("r-1") },
  { keys = "Super+Alt, S",                   action = A.move_ws_silent("special") },
  { keys = "Ctrl+Super, S",                  action = A.toggle_special() },

  -- ============================================================
  -- Alt-Tab cycling — native dispatchers. bring_to_top dropped: cycle_next
  -- already raises the new active window.
  -- ============================================================
  { keys = "Alt, Tab",       action = hl.dsp.window.cycle_next() },
  { keys = "ALT Shift, Tab", action = hl.dsp.window.cycle_next({ prev = true }) },

  -- ============================================================
  -- Workspace focus (1-10)
  -- ============================================================
  { keys = "Super, 1", action = A.focus_ws(1) },
  { keys = "Super, 2", action = A.focus_ws(2) },
  { keys = "Super, 3", action = A.focus_ws(3) },
  { keys = "Super, 4", action = A.focus_ws(4) },
  { keys = "Super, 5", action = A.focus_ws(5) },
  { keys = "Super, 6", action = A.focus_ws(6) },
  { keys = "Super, 7", action = A.focus_ws(7) },
  { keys = "Super, 8", action = A.focus_ws(8) },
  { keys = "Super, 9", action = A.focus_ws(9) },
  { keys = "Super, 0", action = A.focus_ws(10) },

  -- ============================================================
  -- Workspace nav (relative / monitor)
  -- ============================================================
  { keys = "Ctrl+Super, Right",      action = A.focus_ws("r+1") },
  { keys = "Ctrl+Super, Left",       action = A.focus_ws("r-1") },
  { keys = "Ctrl+Super+Alt, Right",  action = A.focus_ws("m+1") },
  { keys = "Ctrl+Super+Alt, Left",   action = A.focus_ws("m-1") },
  { keys = "Super, Page_Down",       action = A.focus_ws("+1") },
  { keys = "Super, Page_Up",         action = A.focus_ws("-1") },
  { keys = "Ctrl+Super, Page_Down",  action = A.focus_ws("r+1") },
  { keys = "Ctrl+Super, Page_Up",    action = A.focus_ws("r-1") },
  { keys = "Super, mouse_up",        action = A.focus_ws("+1") },
  { keys = "Super, mouse_down",      action = A.focus_ws("-1") },
  { keys = "Ctrl+Super, mouse_up",   action = A.focus_ws("r+1") },
  { keys = "Ctrl+Super, mouse_down", action = A.focus_ws("r-1") },
  { keys = "Super, S",               action = A.toggle_special() },
  { keys = "Super, mouse:275",       action = A.toggle_special() },
  { keys = "Ctrl+Super, BracketLeft",  action = A.focus_ws("-1") },
  { keys = "Ctrl+Super, BracketRight", action = A.focus_ws("+1") },
  { keys = "Ctrl+Super, Up",         action = A.focus_ws("r-5") },
  { keys = "Ctrl+Super, Down",       action = A.focus_ws("r+5") },
  { keys = "Super, TAB",             action = A.focus_ws("previous") },

  -- ============================================================
  -- Apps / launchers
  -- ============================================================
  { keys = "Super, Return",  action = A.exec("uwsm-app -- ghostty") },
  { keys = "Ctrl+Super, Backslash", action = A.resize_exact(640, 480) },
  { keys = "Super, W",       action = A.exec("vicinae toggle") },
  { keys = "Super, V",       action = A.exec("vicinae vicinae://extensions/vicinae/clipboard/history") },
  { keys = "Super, C",       action = A.exec("uwsm-app -- clipboard-menu") },
  { keys = "Super, U",       action = A.exec("uwsm-app -- uuctl") },
  { keys = "Super, F12",     action = A.exec("uwsm-app -- /home/killua/.local/bin/switch-session.sh") },
  { keys = "Super ALT, L",   action = A.exec("uwsm-app -- dms ipc call lock lock") },

  -- ============================================================
  -- Scroller layout focus / swap / resize
  -- ============================================================
  { keys = "Super, N",        action = A.layout("focus left") },
  { keys = "Super, O",        action = A.layout("focus right") },
  { keys = "Super, I",        action = A.layout("focus up") },
  { keys = "Super, E",        action = A.layout("focus down") },
  { keys = "Super SHIFT, N",  action = A.layout("swapcol l") },
  { keys = "Super SHIFT, O",  action = A.layout("swapcol r") },
  { keys = "Super SHIFT, E",  action = A.layout("colresize -conf") },
  { keys = "Super SHIFT, I",  action = A.toggle_col_width() },

  -- ============================================================
  -- Move-to-workspace by number (Super+Shift+1..0)
  -- ============================================================
  { keys = "Super SHIFT, 1", action = A.move_ws(1) },
  { keys = "Super SHIFT, 2", action = A.move_ws(2) },
  { keys = "Super SHIFT, 3", action = A.move_ws(3) },
  { keys = "Super SHIFT, 4", action = A.move_ws(4) },
  { keys = "Super SHIFT, 5", action = A.move_ws(5) },
  { keys = "Super SHIFT, 6", action = A.move_ws(6) },
  { keys = "Super SHIFT, 7", action = A.move_ws(7) },
  { keys = "Super SHIFT, 8", action = A.move_ws(8) },
  { keys = "Super SHIFT, 9", action = A.move_ws(9) },
  { keys = "Super SHIFT, 0", action = A.move_ws(10) },

  -- Mouse forward/back: media previous/next
  { keys = "Super+Shift+Alt, mouse:275", action = A.exec("uwsm-app -- playerctl previous") },
  { keys = "Super+Shift+Alt, mouse:276", action = A.exec("uwsm-app -- playerctl next || playerctl position `bc <<< '100 * $(playerctl metadata mpris:length) / 1000000 / 100'`") },

  -- ============================================================
  -- bindle (repeating + locked): volume up/down
  -- ============================================================
  { keys = ", XF86AudioRaiseVolume", repeating = true, locked = true, action = A.exec("uwsm-app -- wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%+") },
  { keys = ", XF86AudioLowerVolume", repeating = true, locked = true, action = A.exec("uwsm-app -- wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%-") },

  -- ============================================================
  -- bindel (repeating): kbd/screen brightness + volume via dms
  -- ============================================================
  { keys = ", XF86KbdBrightnessUp",   repeating = true, action = A.exec("kbdbrite.sh up") },
  { keys = ", XF86KbdBrightnessDown", repeating = true, action = A.exec("kbdbrite.sh down") },
  { keys = ", XF86MonBrightnessUp",   repeating = true, action = A.exec("dms ipc call brightness increment 5") },
  { keys = ", XF86MonBrightnessDown", repeating = true, action = A.exec("dms ipc call brightness decrement 5") },
  { keys = ", XF86AudioRaiseVolume",  repeating = true, action = A.exec("dms ipc call audio increment 3") },
  { keys = ", XF86AudioLowerVolume",  repeating = true, action = A.exec("dms ipc call audio decrement 3") },

  -- ============================================================
  -- bindl (locked = fires while screen locked): media + mute
  -- ============================================================
  { keys = ", XF86AudioMute",       locked = true, action = A.exec("uwsm-app -- wpctl set-mute @DEFAULT_SINK@ toggle") },
  { keys = "Alt, XF86AudioMute",    locked = true, action = A.exec("uwsm-app -- wpctl set-mute @DEFAULT_SOURCE@ toggle") },
  { keys = ", XF86AudioMicMute",    locked = true, action = A.exec("uwsm-app -- wpctl set-mute @DEFAULT_SOURCE@ toggle") },
  { keys = "Super+Shift, N",        locked = true, action = A.exec("uwsm-app -- playerctl next || playerctl position `bc <<< '100 * $(playerctl metadata mpris:length) / 1000000 / 100'`") },
  { keys = ", XF86AudioNext",       locked = true, action = A.exec("uwsm-app -- playerctl next || playerctl position `bc <<< '100 * $(playerctl metadata mpris:length) / 1000000 / 100'`") },
  { keys = ", XF86AudioPrev",       locked = true, action = A.exec("uwsm-app -- playerctl previous") },
  { keys = "Super+Shift, B",        locked = true, action = A.exec("uwsm-app -- playerctl previous") },
  { keys = "Super+Shift, P",        locked = true, action = A.exec("uwsm-app -- playerctl play-pause") },
  { keys = ", XF86AudioPlay",       locked = true, action = A.exec("uwsm-app -- playerctl play-pause") },
  { keys = ", XF86AudioPause",      locked = true, action = A.exec("uwsm-app -- playerctl play-pause") },
  { keys = ", XF86AudioMute",       locked = true, action = A.exec("dms ipc call audio mute") },
  { keys = ", XF86AudioMicMute",    locked = true, action = A.exec("dms ipc call audio micmute") },

  -- ============================================================
  -- bindld (locked + described)
  -- ============================================================
  { keys = "Super+Shift, M", locked = true, desc = "Toggle mute",   action = A.exec("uwsm-app -- wpctl set-mute @DEFAULT_SINK@ toggle") },
  { keys = "Super+Alt, M",   locked = true, desc = "Toggle mic",    action = A.exec("uwsm-app -- wpctl set-mute @DEFAULT_SOURCE@ toggle") },
  { keys = "Super+Shift, L", locked = true, desc = "Suspend system",action = A.exec("uwsm-app -- systemctl suspend || loginctl suspend") },

  -- ============================================================
  -- bindm (mouse drag)
  -- ============================================================
  { keys = "Super, mouse:272", drag = true, action = A.drag() },
  { keys = "Super, mouse:274", drag = true, action = A.drag() },
  { keys = "Super, mouse:273", drag = true, action = A.mresize() },
}

-- Convert legacy hyprlang "MODS, KEY" syntax to hl.bind's "MOD+MOD+KEY".
-- Examples:
--   "Super, 4"          → "SUPER+4"
--   "Super+Shift, Left" → "SUPER+SHIFT+Left"
--   "Super Shift, N"    → "SUPER+SHIFT+N"
--   ", Print"           → "Print"
--   "Ctrl+Alt, Delete"  → "CTRL+ALT+Delete"
local function normalize(keys)
  local comma = keys:find(",")
  if not comma then return keys end
  local mods = keys:sub(1, comma - 1)
  local key  = keys:sub(comma + 1):gsub("^%s+", ""):gsub("%s+$", "")
  -- Split mods on `+` or whitespace, drop empties, uppercase.
  local parts = {}
  for part in mods:gmatch("[^+%s]+") do
    table.insert(parts, part:upper())
  end
  if #parts == 0 then return key end
  table.insert(parts, key)
  return table.concat(parts, "+")
end
M.normalize = normalize

-- Walk M.binds and call hl.bind with the right flags.
function M.register()
  for _, b in ipairs(M.binds) do
    local flags = {}
    if b.desc then flags.description = b.desc end
    if b.repeating then flags.repeating = true end
    if b.locked then flags.locked = true end
    if b.drag then flags.drag = true end
    if b.click then flags.click = true end
    local target = b.action
    if type(target) == "table" and target.fn then target = target.fn end
    hl.bind(normalize(b.keys), target, flags)
  end
end

-- Re-export action helpers so leader.lua / device-keybinds.lua can reuse.
M.A = A
M.hctl = hctl

return M
