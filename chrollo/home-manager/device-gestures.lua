-- Per-host touchpad gestures for chrollo (ThinkPad — real trackpad).
--
-- Host-scoped (loaded via try_require("device-gestures")) rather than shared,
-- so the killua handheld doesn't get workspace-swipe/pinch bound to its small
-- trackpad. Formerly lua/gestures.lua (global) — moved here when chrollo became
-- the only host that wants them.

hl.config({
  gestures = {
    workspace_swipe_distance = 700,
    workspace_swipe_cancel_ratio = 0.2,
    workspace_swipe_min_speed_to_force = 5,
    workspace_swipe_direction_lock = true,
    workspace_swipe_direction_lock_threshold = 10,
    workspace_swipe_create_new = true,
  },
  gesture = {
    "3, swipe, move,",
    "4, horizontal, workspace",
    "4, pinch, float",
    "4, up, dispatcher, global, quickshell:overviewToggle",
    "4, down, dispatcher, global, quickshell:overviewClose",
  },
})
