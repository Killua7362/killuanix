-- NOTE: this just gives nixCats global command a default value
-- so that it doesnt throw an error if you didnt install via nix.
-- usage of both this setup and the nixCats command is optional,
-- but it is very useful for passing info from nix to lua so you will likely use it at least once.
require("nixCatsUtils").setup({
	non_nix_value = true,
})

if not require("nixCatsUtils").isNixCats then
  local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
  if not (vim.uv or vim.loop).fs_stat(lazypath) then
    local lazyrepo = "https://github.com/folke/lazy.nvim.git"
    local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
    if vim.v.shell_error ~= 0 then
      vim.api.nvim_echo({
        { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
        { out, "WarningMsg" },
        { "\nPress any key to exit..." },
      }, true, {})
      vim.fn.getchar()
      os.exit(1)
    end
  end
  vim.opt.rtp:prepend(lazypath)
end

-- NOTE: You might want to move the lazy-lock.json file
local function getlockfilepath()
	if require("nixCatsUtils").isNixCats and type(nixCats.settings.unwrappedCfgPath) == "string" then
		return nixCats.settings.unwrappedCfgPath .. "/lazy-lock.json"
	else
		return vim.fn.stdpath("config") .. "/lazy-lock.json"
	end
end
local lazyOptions = {
	lockfile = getlockfilepath(),
	change_detection = { notify = false },
	checker = {
		enabled = true, -- automatically check for plugin updates
		notify = false, -- get a notification when new updates are found
	},
  defaults = {
    -- By default, only LazyVim plugins will be lazy-loaded. Your custom plugins will load during startup.
    -- If you know what you're doing, you can set this to `true` to have all your custom plugins lazy-loaded by default.
    lazy = false,
    -- It's recommended to leave version=false for now, since a lot the plugin that support versioning,
    -- have outdated releases, which may break your Neovim install.
    version = false, -- always use the latest git commit
    -- version = "*", -- try installing the latest stable version for plugins that support semver
  },
	-- ui config
	ui = {
		border = "rounded",
		size = {
			width = 0.8,
			height = 0.8,
		},
		backdrop = 100,
	},
	performance = {
		rtp = {
			-- disable some rtp plugins
			disabled_plugins = {
				"2html_plugin",
				"tohtml",
				"getscript",
				"getscriptPlugin",
				"gzip",
				"logipat",
				"netrw",
				"netrwPlugin",
				"netrwSettings",
				"netrwFileHandlers",
				"matchit",
				"tar",
				"tarPlugin",
				"rrhelper",
				"spellfile_plugin",
				"vimball",
				"vimballPlugin",
				"zip",
				"zipPlugin",
				"tutor",
				"rplugin",
				"syntax",
				"synmenu",
				"optwin",
				"compiler",
				"bugreport",
			},
		},
	},
	readme = {
		enabled = false,
	},
}

-- NOTE: this the lazy wrapper. Use it like require('lazy').setup() but with an extra
-- argument, the path to lazy.nvim as downloaded by nix, or nil, before the normal arguments.
require("nixCatsUtils.lazyCat").setup(nixCats.pawsible({ "allPlugins", "start", "lazy.nvim" }), {
	{ "LazyVim/LazyVim", import = "lazyvim.plugins" },
	{ import = "lazyvim.plugins.extras.coding.luasnip" },
	{ import = "lazyvim.plugins.extras.coding.mini-surround" },
	{ import = "lazyvim.plugins.extras.dap.core" },
	{ import = "lazyvim.plugins.extras.editor.mini-diff" },
	{ import = "lazyvim.plugins.extras.lang.java" },
	{ import = "lazyvim.plugins.extras.lang.typescript" },
	{ import = "lazyvim.plugins.extras.lang.typescript" },

	-- disable mason.nvim while using nix
	-- precompiled binaries do not agree with nixos, and we can just make nix install this stuff for us.
	{ "mason-org/mason-lspconfig.nvim", enabled = require("nixCatsUtils").lazyAdd(true, false) },
	{
		"mason-org/mason.nvim",
		enabled = require("nixCatsUtils").lazyAdd(true, false),
		opts = {
			ensure_installed = {
				"stylua",
				"shfmt",
				-- "jdtls",
				-- "java-test",
				-- "java-debug-adapter",
				"postgrestools",
				"lua-language-server",
				"sqlfluff",
				"shellcheck",
				"flake8",
			},
		},
	},
	{
		"nvim-treesitter/nvim-treesitter",
		dev = true,
		build = require("nixCatsUtils").lazyAdd(":TSUpdate"),
		opts_extend = require("nixCatsUtils").lazyAdd(nil, false),
		opts = {
			-- nix already ensured they were installed, and we would need to change the parser_install_dir if we wanted to use it instead.
			-- so we just disable install and do it via nix.
			ensure_installed = require("nixCatsUtils").lazyAdd(
				{ "bash", "c", "diff", "html", "lua", "luadoc", "markdown", "vim", "vimdoc" },
				false
			),
			auto_install = require("nixCatsUtils").lazyAdd(true, false),
		},
	},
	{
		"folke/lazydev.nvim",
		opts = {
			library = {
				{ path = (nixCats.nixCatsPath or "") .. "/lua", words = { "nixCats" } },
			},
		},
	},
	-- import/override with your plugins
	{ import = "plugins" },
}, lazyOptions)
