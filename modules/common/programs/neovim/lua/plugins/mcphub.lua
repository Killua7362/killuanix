-- Check if running under nixCats
local isNixCats = require("nixCatsUtils").isNixCats

return {
  "ravitemer/mcphub.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  -- Disable build command when using nixCats (Nix handles the binary)
  build = nil,
  config = function()
    local opts = {}

    -- When using nixCats, get the mcp-hub path from Nix
    if isNixCats then
      local mcpHubPath = nixCats("extra.mcpHub")
      if mcpHubPath then
        opts.cmd = mcpHubPath
      end
    end

    require("mcphub").setup(opts)
    
  end,
}
