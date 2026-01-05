-- Check if running under nixCats
local isNixCats = require("nixCatsUtils").isNixCats

return {
  "ravitemer/mcphub.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  -- Disable build command when using nixCats (Nix handles the binary)
  build = not isNixCats and "npm install -g mcp-hub@latest" or nil,
  config = function()
    local opts = {}

    -- When using nixCats, get the mcp-hub path from Nix
    if isNixCats then
      local mcpHubPath = nixCats("mcpHub")
      if mcpHubPath then
        opts.cmd = mcpHubPath
      end
    end

    require("mcphub").setup(opts)
  end,
}
