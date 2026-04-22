# Neovim Module

nixCats-based Neovim configuration built on LazyVim, using Nix to manage plugins and runtime dependencies while keeping all editor configuration in Lua.

## Nix Side (`default.nix`)

The Nix file sets up nixCats with a single package definition (`nvim`) and one category (`general`).

### Runtime Dependencies (lspsAndRuntimeDeps)

- **LSP servers:** lua-language-server, nil (Nix), jdt-language-server, postgres-language-server, qmlls (configured in lua)
- **Formatters:** stylua, shfmt, sqlfluff
- **Tools:** ripgrep, fd, universal-ctags, curl, lazygit (wrapped with empty config)

### Plugins (startupPlugins)

All plugins are provided via Nix (`pkgs.vimPlugins`), not downloaded at runtime. Mason is disabled when running under nixCats. Key plugins include lazy-nvim, LazyVim, blink-cmp, telescope, snacks, treesitter (with all grammars), nvim-dap, conform, trouble, bufferline, gitsigns, lualine, noice, which-key, and catppuccin/mini family.

### Package Settings

- Uses `neovim-nightly-overlay` as the base neovim-unwrapped
- Python3 and Node.js hosts enabled
- `wrapRc = true` -- Lua config is bundled into the Nix derivation
- Extra paths passed to Lua: jdtls, lombok, java-debug-adapter, java-test, debugpy, lldb/codelldb, delve, bashdb

## Lua Side

### Directory Structure

```
lua/
  config/          -- Core editor settings (loaded by LazyVim conventions)
    options.lua    -- Vim options (clipboard, autoformat off, animations off)
    keymaps.lua    -- Custom keymaps (Colemak remappings, window nav, formatting)
    autocmds.lua   -- Autocommands
    general.lua    -- General config
    companion-notif.lua -- Notification handler for CodeCompanion
  nixCatsUtils/    -- nixCats bootstrap utilities
    init.lua       -- Provides nixCats global with fallback for non-Nix usage
    lazyCat.lua    -- Lazy.nvim wrapper that resolves Nix-provided plugin paths
  plugins/         -- Per-plugin configuration specs (imported via lazy.nvim)
    init.lua       -- Empty (placeholder)
    ...            -- Individual plugin configs (see listing below)
```

### Entry Point (`init.lua`)

Sets up nixCatsUtils, bootstraps lazy.nvim (with Nix path resolution), imports LazyVim base plugins plus extras (luasnip, mini-surround, dap.core, lang.java, lang.typescript), disables Mason when under nixCats, configures treesitter to skip installs on Nix, and loads all files from `plugins/`.

## Plugin Listing

| File | Plugin | Purpose |
|---|---|---|
| `aider.lua` | nvim-aider | AI coding assistant terminal integration (currently disabled) |
| `bufferline.lua` | bufferline.nvim | Tab/buffer bar with LSP diagnostics, Colemak-remapped cycle keys (S-N/S-O) |
| `codecompanion.lua` | codecompanion.nvim | LLM chat/inline assistant with multiple adapters (DeepSeek variants, Qwen, Kimi, GLM) via Chutes API; includes history extension, markview rendering, and img-clip |
| `conform.lua` | conform.nvim | Formatter configuration: stylua (Lua), fish_indent, shfmt (shell), sqlfluff (SQL/PostgreSQL) |
| `dap.lua` | nvim-dap | Debug Adapter Protocol with nixCats-aware adapter setup for Python (debugpy), C/C++/Rust (lldb/codelldb), Go (delve), JS/TS (node), Bash (bashdb), Lua; uses nvim-dap-view for UI |
| `diffview.lua` | diffview.nvim | Git diff/file-history viewer with Colemak-adapted panel keys (e/i for next/prev entry); `<leader>gd/gh/gH/gq` to open, history, all-history, close |
| `git-worktree.lua` | git-worktree.nvim | Git worktree management via snacks picker; `<leader>gw` list, `<leader>gW` switch to existing branch, `<leader>gN` create new branch worktree |
| `gitsigns.lua` | gitsigns.nvim | Git gutter signs, hunk navigation/staging/reset, blame, diff |
| `java.lua` | nvim-jdtls | Java LSP with nixCats-aware paths for jdtls, lombok, debug adapter, and test bundles; which-key integration for extract/organize/test commands |
| `lsp.lua` | nvim-lspconfig | LSP server overrides (adds qmlls with qmlls6 command) |
| `lualine.lua` | lualine.nvim | Statusline: mode, branch, diagnostics, path, noice command/mode, DAP status, diff, clock |
| `marks.lua` | marks.nvim | Visual mark indicators in the sign column with bookmark groups |
| `mcphub.lua` | mcphub.nvim | MCP (Model Context Protocol) hub integration (currently disabled) |
| `mini.ai.lua` | mini.ai | Enhanced text objects (code blocks, functions, classes, tags, digits, camelCase); `u` mapped to "inside" for Colemak |
| `mini.misc.lua` | mini.misc | Utility functions; `setup_auto_root` made global for root-dir detection |
| `mini.surround.lua` | mini.surround | Surround operations with `gs` prefix (gsa/gsd/gsf/gsr) |
| `neoconf.lua` | neoconf.nvim | Project-local LSP settings via `.neoconf.json` |
| `oil.lua` | oil.nvim | File explorer as a buffer (not default explorer); mapped to `-` |
| `opencode.lua` | opencode.nvim | OpenCode AI assistant integration via sidekick.nvim; toggle with `<C-.>`, ask with `<leader>oa`, select with `<C-x>` |
| `sidekick.lua` | sidekick.nvim | Terminal-based AI CLI runner (backend: zellij); provides window for opencode |
| `snacks.lua` | snacks.nvim | Picker config with Colemak-adapted keys (i/e/n/o for up/down/left/right), flash integration, trouble integration, scope text objects |
| `trouble.lua` | trouble.nvim | Diagnostics list with snacks picker integration (T to open) |
| `ui.lua` | bufferline.nvim | Additional bufferline opts -- filters out directory buffers |
| `vscode.theme.lua` | vscode.nvim | VS Code Dark theme with transparent background; set as the active colorscheme |
| `zellij-nav.lua` | zellij-nav.nvim | Zellij pane/tab navigation with `<Alt-n/e/i/o>` (Colemak NEIO) |

## Notable Details

- **Leader key:** Space (LazyVim default)
- **Colemak layout:** Extensive remappings in `keymaps.lua` -- NEIO replaces HJKL for navigation, `u` is insert, `y`/`Y` is open line, `h`/`H` is next/prev search, `k` is undo, `l` is yank. Window navigation uses `<C-w>n/e/i/o`. These remappings are consistently applied across snacks picker, zellij-nav, bufferline, and sidekick.
- **Colorscheme:** VS Code Dark (transparent background)
- **AI integrations:** CodeCompanion (primary, with multiple LLM adapters via Chutes API), OpenCode (via sidekick.nvim/zellij), Aider (disabled), MCPHub (disabled)
- **DAP adapters:** All debug adapter paths are injected from Nix via `nixCats("extra.*")` and `nixCats("debugAdapters.*")` -- no Mason on NixOS
- **Formatting:** `<leader>cf` triggers conform.nvim with async + LSP fallback; autoformat is off by default
