return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      ['*'] = {
        keys = {
          {"<a-n>",false}
        }
      },
      qmlls = {
        cmd = {"qmlls6", "-E"}
      }
    }
  }
}
