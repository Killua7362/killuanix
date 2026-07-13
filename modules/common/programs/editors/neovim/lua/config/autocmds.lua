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

-- Announce to WezTerm that this pane runs nvim, via an OSC 1337 user var.
-- WezTerm's autolock passthrough (wezterm.nix) reads pane:get_user_vars().IS_NVIM
-- and forwards its modal chords (Ctrl-p/t/n/h/m/s) to nvim instead of grabbing
-- them. This is the only signal that survives the `wezterm connect unix` mux —
-- get_foreground_process_name()/get_tty_name() return nil for mux panes.
local wezterm_grp = vim.api.nvim_create_augroup("wezterm_is_nvim", { clear = true })
local function set_is_nvim(value)
	io.stdout:write(string.format("\027]1337;SetUserVar=IS_NVIM=%s\007", vim.base64.encode(value)))
end
vim.api.nvim_create_autocmd({ "VimEnter", "VimResume" }, {
	group = wezterm_grp,
	pattern = "*",
	callback = function()
		set_is_nvim("true")
	end,
})
vim.api.nvim_create_autocmd({ "VimLeave", "VimSuspend" }, {
	group = wezterm_grp,
	pattern = "*",
	callback = function()
		set_is_nvim("false")
	end,
})

vim.api.nvim_create_autocmd({ "FileType" }, {
	pattern = { "dap-view", "dap-view-term", "dap-repl" }, -- dap-repl is set by `nvim-dap`
	callback = function(args)
		vim.keymap.set("n", "q", "<C-w>q", { buffer = args.buf })
		vim.keymap.set({ "n", "i" }, "<C-n>", "<down>", { buffer = args.buf })
		vim.keymap.set({ "n", "i" }, "<C-p>", "<up>", { buffer = args.buf })
	end,
})
