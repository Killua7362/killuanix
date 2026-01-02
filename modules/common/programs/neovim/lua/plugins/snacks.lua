return {
  "folke/snacks.nvim",
  opts = {
    scope = {
      ---@class snacks.scope.Config
      ---@field max_size? number
      ---@field enabled? boolean
      keys = {
        ---@type table<string, snacks.scope.TextObject|{desc?:string}>
        textobject = {
          ii = {
            min_size = 2, -- minimum size of the scope
            edge = false, -- inner scope
            cursor = false,
            treesitter = { blocks = { enabled = false } },
            desc = "inner scope",
          },
          ai = {
            cursor = false,
            min_size = 2, -- minimum size of the scope
            treesitter = { blocks = { enabled = false } },
            desc = "full scope",
          },
        },
      },
    },
    picker = {
      win = {
        input = {
          keys = {
              ["E"] = { "preview_scroll_down", mode = { "i", "n" } },
              ["I"] = { "preview_scroll_up", mode = { "i", "n" } },
              ["N"] = { "preview_scroll_left", mode = { "i", "n" } },
              ["O"] = { "preview_scroll_right", mode = { "i", "n" } },
            -- ["<c-l>"] = { "preview_scroll_left", mode = { "i", "n" } },
            -- ["<c-r>"] = { "preview_scroll_right", mode = { "i", "n" } },
            ["<a-c>"] = {
              "toggle_cwd",
              mode = { "n", "i" },
            },
            ["<a-t>"] = {
              "trouble_open",
              mode = { "n", "i" },
            },
            ["<a-s>"] = { "flash", mode = { "n", "i" } },
            ["s"] = { "flash" },
            ["i"] = { "list_up" },
            ["k"] = { "focus_input" },
            ["<c-h>"] = { "edit_split", mode = { "i", "n" } },
          },
        },
        list = {
          keys = {
            ["i"] = { "list_up" },
            ["k"] = { "focus_input" },
            ["<c-h>"] = "edit_split",
            -- ["<c-l>"] = { "preview_scroll_left", mode = { "i", "n" } },
            -- ["<c-r>"] = { "preview_scroll_right", mode = { "i", "n" } },
          },
        },
      },
      actions = {
        ---@param p snacks.Picker
        toggle_cwd = function(p)
          local root = LazyVim.root({ buf = p.input.filter.current_buf, normalize = true })
          local cwd = vim.fs.normalize((vim.uv or vim.loop).cwd() or ".")
          local current = p:cwd()
          p:set_cwd(current == root and cwd or root)
          p:find()
        end,
        trouble_open = function(...)
          return require("trouble.sources.snacks").actions.trouble_open.action(...)
        end,
        flash = function(picker)
          require("flash").jump({
            pattern = "^",
            label = { after = { 0, 0 } },
            search = {
              mode = "search",
              exclude = {
                function(win)
                  return vim.bo[vim.api.nvim_win_get_buf(win)].filetype ~= "snacks_picker_list"
                end,
              },
            },
            action = function(match)
              local idx = picker.list:row2idx(match.pos[1])
              picker.list:_move(idx, true, true)
            end,
          })
        end,
      },
    },
  },
}
