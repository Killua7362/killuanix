return {
  "sindrets/diffview.nvim",
  cmd = { "DiffviewOpen", "DiffviewFileHistory", "DiffviewClose" },
  keys = {
    { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Diffview Open" },
    { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "File History (current)" },
    { "<leader>gH", "<cmd>DiffviewFileHistory<cr>", desc = "File History (all)" },
    { "<leader>gq", "<cmd>DiffviewClose<cr>", desc = "Diffview Close" },
  },
  opts = {
    enhanced_diff_hl = true,
    view = {
      default = { winbar_info = true },
      file_history = { winbar_info = true },
    },
    keymaps = {
      view = {
        -- Disable defaults that conflict with Colemak
        { "n", "e", false },
        { "n", "o", false },
        { "n", "i", false },
        { "n", "n", false },
        -- Colemak: <leader>e to focus file panel (default was <leader>e, keep it)
        { "n", "<leader>e", "focus_files", { desc = "Focus file panel" } },
        { "n", "<leader>b", "toggle_files", { desc = "Toggle file panel" } },
      },
      file_panel = {
        -- Disable defaults that conflict with Colemak
        { "n", "j", false },
        { "n", "k", false },
        { "n", "o", false },
        { "n", "l", false },
        { "n", "i", false },
        { "n", "y", false },
        -- Navigation: e/i for down/up (Colemak j/k)
        { "n", "e", "next_entry", { desc = "Next entry" } },
        { "n", "i", "prev_entry", { desc = "Previous entry" } },
        -- Open: <cr> to select, gf for file
        { "n", "<cr>", "select_entry", { desc = "Open diff" } },
        -- Toggle list/tree: u (Colemak i)
        { "n", "u", "listing_style", { desc = "Toggle list/tree" } },
        -- Stage/unstage with s/- (defaults)
        { "n", "L", "open_commit_log", { desc = "Open commit log" } },
      },
      file_history_panel = {
        -- Disable defaults that conflict with Colemak
        { "n", "j", false },
        { "n", "k", false },
        { "n", "o", false },
        { "n", "l", false },
        { "n", "y", false },
        -- Navigation: e/i for down/up (Colemak j/k)
        { "n", "e", "next_entry", { desc = "Next entry" } },
        { "n", "i", "prev_entry", { desc = "Previous entry" } },
        -- Open
        { "n", "<cr>", "select_entry", { desc = "Open diff" } },
        -- Copy hash: use gl (Colemak y → open line, so remap copy to gl)
        { "n", "gl", "copy_hash", { desc = "Copy commit hash" } },
        { "n", "L", "open_commit_log", { desc = "Show commit details" } },
      },
    },
  },
}
