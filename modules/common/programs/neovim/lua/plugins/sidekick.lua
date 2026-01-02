return {
  "folke/sidekick.nvim",
  opts = {
    nes = { enabled = false },
    cli = {
      watch = true,
      win = {
        keys = {
          nav_left      = { "<a-n>", "nav_left"  , expr = true, desc = "navigate to the left window" },
          nav_down      = { "<a-e>", "nav_down"  , expr = true, desc = "navigate to the below window" },
          nav_up        = { "<a-i>", "nav_up"    , expr = true, desc = "navigate to the above window" },
          nav_right     = { "<a-o>", "nav_right" , expr = true, desc = "navigate to the right window" },
        }
      },
      mux = {
        backend = "zellij",
        enabled = true,
      },
      tools = {
        opencode = {
          cmd = { "opencode" },
          -- HACK: https://github.com/sst/opencode/issues/445
          env = { OPENCODE_THEME = "system" },
        },
      }
    },
  },
  keys = {
    -- {
    --   "<c-.>",
    --   function() require("sidekick.cli").toggle({name = "opencode",focus = true}) end,
    --   desc = "Sidekick Toggle",
    --   mode = { "n", "t", "i", "x" },
    -- },
    -- {
    --   "<leader>aa",
    --   function() require("sidekick.cli").toggle({name = "opencode",focus = true}) end,
    --   desc = "Sidekick Toggle CLI",
    -- },
    -- {
    --   "<leader>ad",
    --   function() require("sidekick.cli").close() end,
    --   desc = "Detach a CLI Session",
    -- },
    -- {
    --   "<leader>at",
    --   function() require("sidekick.cli").send({ msg = "{this}" }) end,
    --   mode = { "x", "n" },
    --   desc = "Send This",
    -- },
    -- {
    --   "<leader>af",
    --   function() require("sidekick.cli").send({ msg = "{file}" }) end,
    --   desc = "Send File",
    -- },
    -- {
    --   "<leader>av",
    --   function() require("sidekick.cli").send({ msg = "{selection}" }) end,
    --   mode = { "x" },
    --   desc = "Send Visual Selection",
    -- },
    -- {
    --   "<leader>ap",
    --   function() require("sidekick.cli").prompt() end,
    --   mode = { "n", "x" },
    --   desc = "Sidekick Select Prompt",
    -- },
  },
}
