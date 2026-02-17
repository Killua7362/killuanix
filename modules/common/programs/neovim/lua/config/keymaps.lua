-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
--

local function nnoremap(mode, to, from, desc)
  return vim.keymap.set(mode, to, from, { noremap = true, silent = true, nowait = true, desc = desc })
end

-- formatting
vim.keymap.set({ "n", "x" }, "<leader>cf", function()
  require("conform").format({ async = true, lsp_fallback = true })
end, { desc = "Format" })

--some standard rebindings for colemak
nnoremap({ "n", "v" }, "n", "h")
nnoremap({ "n", "v" }, "e", "j")
nnoremap({ "n", "v" }, "i", "k")
nnoremap({ "n", "v" }, "o", "l")
nnoremap({ "n", "v" }, "u", "i")
nnoremap({ "n", "v" }, "y", "o")
nnoremap({ "n", "v" }, "Y", "O")
nnoremap({ "n", "v" }, "j", "e")
nnoremap({ "n", "v" }, "h", "n")
nnoremap({ "n", "v" }, "H", "N")
nnoremap({ "n", "v" }, "l", "ygv<Esc>")
nnoremap({ "n", "v" }, "k", "u")
nnoremap({ "n" }, "ll", "yy")

nnoremap("n", "{", "<C-u>zz")
nnoremap("v", "{", "<C-u>zz")
nnoremap("n", "}", "<C-d>zz")
nnoremap("v", "}", "<C-d>zz")
nnoremap("n", "<C-u>", "{")
nnoremap("v", "<C-u>", "{")
nnoremap("n", "<C-d>", "}")
nnoremap("v", "<C-d>", "}")

--for tab indenting
nnoremap("v", "<Tab>", ">gv")
nnoremap("v", "<S-TAB>", "<gv")

--moving selected lines up and downnnnn
nnoremap("x", "k", ":move '<-2<cr>gv=gv")
nnoremap("x", "K", ":move '>+2<cr>gv=gv")

vim.api.nvim_set_keymap("n", "<leader>/", ":normal A;<cr>", {})
vim.api.nvim_set_keymap("v", "<leader>/", ":'<,'>normal A;<cr>", {})

-- register magic ig
nnoremap("v", "<Leader>dd", '"_dd')
nnoremap("n", "<Leader>dd", '"_dd')

--copy to void register
nnoremap("x", "<leader>pp", '"_dP')

nnoremap({ "x", "n", "o", "v", "t" }, "<C-w>n", ":wincmd h<cr>", "Go to the left window")
nnoremap({ "x", "n", "o", "v", "t" }, "<C-w>e", ":wincmd j<cr>", "Go to the bottom window")
nnoremap({ "x", "n", "o", "v", "t" }, "<C-w>i", ":wincmd k<cr>", "Go to the top window")
nnoremap({ "x", "n", "o", "v", "t" }, "<C-w>o", ":wincmd l<cr>", "Go to the right window")
nnoremap({ "x", "n", "o", "v", "t" }, "<C-w>w", ":bdelete<cr>", "Close buffer")

vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory" })
vim.keymap.set("n", "<leader>cd", ":cd %:p:h<CR>", { desc = "Cd to current buffer" })
-- vim.keymap.set("n", "gl", vim.diagnostic.open_float, { desc = "Line Diagnostics" })
vim.g.initial_dir = vim.fn.getcwd()

-- Keymap to return to the initial directory
vim.keymap.set("n", "<leader>cD", function()
  vim.cmd("cd " .. vim.g.initial_dir)
end, { desc = "Cd to initial directory" })

-- nnoremap(
--   { "n" },
--   "<leader>ff",
--   LazyVim.pick("files", { cwd = require("mini.misc").find_root(), live = true, regex = true }),
--   "Find Files (root dir)"
-- )

nnoremap(
  { "n" },
  "<leader>ff",
  "<cmd> FFFSnacks <cr>",
  "FFF search"
)

nnoremap({ "n" }, "<leader>fE", function()
  Snacks.explorer()
end, "Explorer Snacks (cwd)")

nnoremap({ "n" }, "<leader>fe", function()
  Snacks.explorer({ cwd = require("mini.misc").find_root() })
end, "Explorer Snacks (root dir)")
