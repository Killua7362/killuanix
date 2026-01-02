return {
  "swaits/zellij-nav.nvim",
  lazy = true,
  event = "VeryLazy",
  keys = {
    { "<a-n>", "<cmd>ZellijNavigateLeftTab<cr>", { silent = true, desc = "navigate left or tab" } },
    { "<a-e>", "<cmd>ZellijNavigateDownTab<cr>", { silent = true, desc = "navigate down" } },
    { "<a-i>", "<cmd>ZellijNavigateUpTab<cr>", { silent = true, desc = "navigate up" } },
    { "<a-o>", "<cmd>ZellijNavigateRightTab<cr>", { silent = true, desc = "navigate right or tab" } },
  },
  opts = {},
}
