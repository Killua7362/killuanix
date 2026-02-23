-- Check if running under nixCats
local isNixCats = require("nixCatsUtils").isNixCats

return {
  "ravitemer/mcphub.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  config = function()
      require("mcphub").setup({
          port = 31415,
          auto_start = false,
          config = vim.fn.expand("~/.config/mcphub/servers.json"),
      })
  end
}
