-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- vim.api.nvim_create_autocmd("FileType", {
--   pattern = "java",
--   callback = function(args)
--     require("config.lsp.jdtls").setup()
--   end,
-- })

vim.api.nvim_create_autocmd("VimLeave", {
  pattern = "*",
  command = "silent !zellij action switch-mode normal",
})

vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = { "dap-view", "dap-view-term", "dap-repl" }, -- dap-repl is set by `nvim-dap`
  callback = function(args)
    vim.keymap.set("n", "q", "<C-w>q", { buffer = args.buf })
    vim.keymap.set({"n","i"}, "<C-n>", "<down>", { buffer = args.buf })
    vim.keymap.set({"n","i"}, "<C-p>", "<up>", { buffer = args.buf })
  end,
})
