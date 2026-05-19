-- General settings. Ported from general.nix.

hl.config({
  general = {
    ["col.active_border"] = "rgba(777777AA)",
    ["col.inactive_border"] = "rgba(c6c6c6AA)",
    gaps_in = 5,
    gaps_out = 10,
    border_size = 1,
    layout = "scrolling",
    gaps_workspaces = 50,
    resize_on_border = true,
    no_focus_fallback = true,
    allow_tearing = true,
    snap = {
      enabled = true,
      window_gap = 4,
      monitor_gap = 5,
      respect_gaps = true,
    },
  },
})
