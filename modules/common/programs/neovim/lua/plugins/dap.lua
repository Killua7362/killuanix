---@param config {type?:string, args?:string[]|fun():string[]?}
local function get_args(config)
  local args = type(config.args) == "function" and (config.args() or {}) or config.args or {} --[[@as string[] | string ]]
  local args_str = type(args) == "table" and table.concat(args, " ") or args --[[@as string]]

  config = vim.deepcopy(config)
  ---@cast args string[]
  config.args = function()
    local new_args = vim.fn.expand(vim.fn.input("Run with args: ", args_str)) --[[@as string]]
    if config.type and config.type == "java" then
      ---@diagnostic disable-next-line: return-type-mismatch
      return new_args
    end
    return require("dap.utils").splitstr(new_args)
  end
  return config
end

return {
  {
    "mfussenegger/nvim-dap",
    recommended = true,
    desc = "Debugging support. Requires language specific adapters to be configured. (see lang extras)",

    dependencies = {
      -- "rcarriga/nvim-dap-ui",
      "igorlfs/nvim-dap-view",
      -- virtual text for the debugger
      {
        "theHamsta/nvim-dap-virtual-text",
        opts = {},
      },
    },

    -- stylua: ignore
    keys = {
      { "<leader>dB", function() require("dap").set_breakpoint(vim.fn.input('Breakpoint condition: ')) end, desc = "Breakpoint Condition" },
      { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "Toggle Breakpoint" },
      { "<leader>dc", function() require("dap").continue() end, desc = "Run/Continue" },
      { "<leader>da", function() require("dap").continue({ before = get_args }) end, desc = "Run with Args" },
      { "<leader>dC", function() require("dap").run_to_cursor() end, desc = "Run to Cursor" },
      { "<leader>dg", function() require("dap").goto_() end, desc = "Go to Line (No Execute)" },
      { "<leader>dj", function() require("dap").down() end, desc = "Down" },
      { "<leader>dk", function() require("dap").up() end, desc = "Up" },
      { "<leader>dl", function() require("dap").run_last() end, desc = "Run Last" },
      { "F2", function() require("dap").step_over() end, desc = "Step Over" },
      { "F3", function() require("dap").step_out() end, desc = "Step Out" },
      { "F4", function() require("dap").step_into() end, desc = "Step Into" },
      { "<leader>dO", function() require("dap").step_over() end, desc = "Step Over" },
      { "<leader>do", function() require("dap").step_out() end, desc = "Step Out" },
      { "<leader>di", function() require("dap").step_into() end, desc = "Step Into" },
      { "<leader>dP", function() require("dap").pause() end, desc = "Pause" },
      { "<leader>dr", function() require("dap").repl.toggle() end, desc = "Toggle REPL" },
      { "<leader>ds", function() require("dap").session() end, desc = "Session" },
      { "<leader>dt", function() require("dap").terminate() end, desc = "Terminate" },
      { "<leader>dw", function() require("dap.ui.widgets").hover() end, desc = "Widgets" },
    },

    config = function()
      -- load mason-nvim-dap here, after all adapters have been setup
      if LazyVim.has("mason-nvim-dap.nvim") then
        require("mason-nvim-dap").setup(LazyVim.opts("mason-nvim-dap.nvim"))
      end

      vim.api.nvim_set_hl(0, "DapStoppedLine", { default = true, link = "Visual" })

      for name, sign in pairs(LazyVim.config.icons.dap) do
        sign = type(sign) == "table" and sign or { sign }
        vim.fn.sign_define(
          "Dap" .. name,
          { text = sign[1], texthl = sign[2] or "DiagnosticInfo", linehl = sign[3], numhl = sign[3] }
        )
      end

      -- setup dap config by VsCode launch.json file
      local vscode = require("dap.ext.vscode")
      local json = require("plenary.json")
      vscode.json_decode = function(str)
        return vim.json.decode(json.json_strip_comments(str))
      end
    end,
  },
  {
    {
      "igorlfs/nvim-dap-view",
      ---@module 'dap-view'
      ---@type dapview.Config
      opts = {
        winbar = {
          controls = {
            enabled = true,
            buttons = { "play", "step_into", "step_over", "step_out", "term_restart", "fun" },
            custom_buttons = {
              fun = {
                render = function()
                  return "🎉"
                end,
                action = function()
                  vim.print("🎊")
                end,
              },
              -- Stop | Restart
              -- Double click, middle click or click with a modifier disconnect instead of stopping
              term_restart = {
                render = function(session)
                  local group = session and "ControlTerminate" or "ControlRunLast"
                  local icon = session and "" or ""
                  return "%#NvimDapView" .. group .. "#" .. icon .. "%*"
                end,
                action = function(clicks, button, modifiers)
                  local dap = require("dap")
                  local alt = clicks > 1 or button ~= "l" or modifiers:gsub(" ", "") ~= ""
                  if not dap.session() then
                    dap.run_last()
                  elseif alt then
                    dap.disconnect()
                  else
                    dap.terminate()
                  end
                end,
              },
            },
          },
          base_sections = {
            breakpoints = {
              keymap = "B",
              label = "Breakpoints [B]",
              short_label = " [B]",
              action = function()
                require("dap-view.views").switch_to_view("breakpoints")
              end,
            },
            scopes = {
              keymap = "S",
              label = "Scopes [S]",
              short_label = "󰂥 [S]",
              action = function()
                require("dap-view.views").switch_to_view("scopes")
              end,
            },
            exceptions = {
              keymap = "J",
              label = "Exceptions [J]",
              short_label = "󰢃 [J]",
              action = function()
                require("dap-view.views").switch_to_view("exceptions")
              end,
            },
            watches = {
              keymap = "W",
              label = "Watches [W]",
              short_label = "󰛐 [W]",
              action = function()
                require("dap-view.views").switch_to_view("watches")
              end,
            },
            threads = {
              keymap = "T",
              label = "Threads [T]",
              short_label = "󱉯 [T]",
              action = function()
                require("dap-view.views").switch_to_view("threads")
              end,
            },
            repl = {
              keymap = "R",
              label = "REPL [R]",
              short_label = "󰯃 [R]",
              action = function()
                require("dap-view.repl").show()
              end,
            },
            sessions = {
              keymap = "K", -- I ran out of mnemonics
              label = "Sessions [K]",
              short_label = " [K]",
              action = function()
                require("dap-view.views").switch_to_view("sessions")
              end,
            },
            console = {
              keymap = "C",
              label = "Console [C]",
              short_label = "󰆍 [C]",
              action = function()
                require("dap-view.views").switch_to_view("console")
              end,
            },
          },
        },
      },
      keys = {
        {
          "<leader>du",
          function()
            require("dap-view").toggle(true)
          end,
          desc = "Dap View",
        },
      },
      config = function(_, opts)
        local dap = require("dap")
        local dapui = require("dap-view")
        dapui.setup(opts)
        dap.listeners.after.event_initialized["dapui_config"] = function()
          dapui.open()
        end
        dap.listeners.before.event_terminated["dapui_config"] = function()
          dapui.close()
        end
        dap.listeners.before.event_exited["dapui_config"] = function()
          dapui.close()
        end
      end,
    },
  },
  -- fancy UI for the debugger
  {
    "rcarriga/nvim-dap-ui",
    enabled = false,
    dependencies = { "nvim-neotest/nvim-nio" },
    -- stylua: ignore
    keys = {
      { "<leader>du", function() require("dapui").toggle({ }) end, desc = "Dap UI" },
      { "<leader>de", function() require("dapui").eval() end, desc = "Eval", mode = {"n", "x"} },
    },
    opts = {},
    config = function(_, opts)
      local dap = require("dap")
      local dapui = require("dapui")
      dapui.setup(opts)
      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open({})
      end
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close({})
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close({})
      end
    end,
  },

  -- mason.nvim integration
  {
    "jay-babu/mason-nvim-dap.nvim",
    dependencies = "mason.nvim",
    cmd = { "DapInstall", "DapUninstall" },
    opts = {
      -- Makes a best effort to setup the various debuggers with
      -- reasonable debug configurations
      automatic_installation = true,

      -- You can provide additional configuration to the handlers,
      -- see mason-nvim-dap README for more information
      handlers = {},

      -- You'll need to check that you have the required things installed
      -- online, please don't ask me how to install them :)
      ensure_installed = {
        -- Update this to ensure that you have the debuggers for the langs you want
      },
    },
    -- mason-nvim-dap is loaded when nvim-dap loads
    config = function() end,
  },
}
