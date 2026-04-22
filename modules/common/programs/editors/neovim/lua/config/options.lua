-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
--
-- integration works automatically.
vim.opt.clipboard = "unnamedplus" -- Sync with system clipboard
vim.g.autoformat = false
vim.g.snacks_animate = false

-- Match terminal neovim look when running in a GUI (Neovide, nvim-qt, etc.)
vim.o.guifont = "JetBrainsMono Nerd Font:h12"
if vim.g.neovide then
	vim.g.neovide_opacity = 1.0
	vim.g.neovide_background_color = "#131313"
	vim.g.neovide_cursor_animation_length = 0
	vim.g.neovide_cursor_trail_size = 0
	vim.g.neovide_scroll_animation_length = 0
	vim.g.neovide_position_animation_length = 0
	vim.g.neovide_floating_shadow = false
end
