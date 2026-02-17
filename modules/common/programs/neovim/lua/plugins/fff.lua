return {
  {
    "dmtrKovalenko/fff.nvim",
    build = "nix run .#release",
    lazy = false, -- make fff initialize on startup
  },

  {
    "madmaxieee/fff-snacks.nvim",
    dependencies = {
      "dmtrKovalenko/fff.nvim",
      "folke/snacks.nvim",
    },
    cmd = "FFFSnacks",
    keys = {
      {
        "<leader>ff",
        "<cmd> FFFSnacks <cr>",
        desc = "FFF",
      },
    },
    config = true,
  },
}
