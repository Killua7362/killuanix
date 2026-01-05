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

-- Check if running under nixCats
local isNixCats = require("nixCatsUtils").isNixCats

return {
  {
    "mfussenegger/nvim-dap",
    recommended = true,
    desc = "Debugging support. Requires language specific adapters to be configured. (see lang extras)",

    dependencies = {
      "igorlfs/nvim-dap-view",
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
      local dap = require("dap")

      -- Only use mason-nvim-dap when NOT using nixCats
      if not isNixCats and LazyVim.has("mason-nvim-dap.nvim") then
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

      -- Setup dap config by VsCode launch.json file
      local vscode = require("dap.ext.vscode")
      local json = require("plenary.json")
      vscode.json_decode = function(str)
        return vim.json.decode(json.json_strip_comments(str))
      end

      -- ═══════════════════════════════════════════════════════════════════
      -- nixCats DAP Adapter Configuration
      -- Adapters are passed via extra arguments from Nix
      -- ═══════════════════════════════════════════════════════════════════
      if isNixCats then
        -- Get adapter paths from nixCats extra arguments
        -- These should be defined in your Nix configuration
        local debugAdapters = nixCats("debugAdapters") or {}

        -- ─────────────────────────────────────────────────────────────────
        -- Python (debugpy)
        -- ─────────────────────────────────────────────────────────────────
        if debugAdapters.python then
          dap.adapters.python = {
            type = "executable",
            command = debugAdapters.python,
            args = { "-m", "debugpy.adapter" },
          }
          dap.configurations.python = {
            {
              type = "python",
              request = "launch",
              name = "Launch file",
              program = "${file}",
              pythonPath = function()
                local venv = os.getenv("VIRTUAL_ENV")
                if venv then
                  return venv .. "/bin/python"
                end
                return debugAdapters.python
              end,
            },
          }
        end

        -- ─────────────────────────────────────────────────────────────────
        -- C/C++/Rust (lldb-vscode / codelldb)
        -- ─────────────────────────────────────────────────────────────────
        if debugAdapters.lldb then
          dap.adapters.lldb = {
            type = "executable",
            command = debugAdapters.lldb,
            name = "lldb",
          }
          dap.configurations.cpp = {
            {
              name = "Launch",
              type = "lldb",
              request = "launch",
              program = function()
                return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
              end,
              cwd = "${workspaceFolder}",
              stopOnEntry = false,
              args = {},
            },
          }
          dap.configurations.c = dap.configurations.cpp
          dap.configurations.rust = dap.configurations.cpp
        end

        -- Alternative: codelldb
        if debugAdapters.codelldb then
          dap.adapters.codelldb = {
            type = "server",
            port = "${port}",
            executable = {
              command = debugAdapters.codelldb,
              args = { "--port", "${port}" },
            },
          }
        end

        -- ─────────────────────────────────────────────────────────────────
        -- Go (delve)
        -- ─────────────────────────────────────────────────────────────────
        if debugAdapters.delve then
          dap.adapters.delve = {
            type = "server",
            port = "${port}",
            executable = {
              command = debugAdapters.delve,
              args = { "dap", "-l", "127.0.0.1:${port}" },
            },
          }
          dap.configurations.go = {
            {
              type = "delve",
              name = "Debug",
              request = "launch",
              program = "${file}",
            },
            {
              type = "delve",
              name = "Debug Package",
              request = "launch",
              program = "${workspaceFolder}",
            },
            {
              type = "delve",
              name = "Debug test",
              request = "launch",
              mode = "test",
              program = "${file}",
            },
            {
              type = "delve",
              name = "Debug test (go.mod)",
              request = "launch",
              mode = "test",
              program = "./${relativeFileDirname}",
            },
          }
        end

        -- ─────────────────────────────────────────────────────────────────
        -- JavaScript/TypeScript (node-debug2 / js-debug)
        -- ─────────────────────────────────────────────────────────────────
        if debugAdapters.node then
          dap.adapters.node2 = {
            type = "executable",
            command = "node",
            args = { debugAdapters.node },
          }
          dap.configurations.javascript = {
            {
              name = "Launch",
              type = "node2",
              request = "launch",
              program = "${file}",
              cwd = vim.fn.getcwd(),
              sourceMaps = true,
              protocol = "inspector",
              console = "integratedTerminal",
            },
            {
              name = "Attach to process",
              type = "node2",
              request = "attach",
              processId = require("dap.utils").pick_process,
            },
          }
          dap.configurations.typescript = dap.configurations.javascript
        end

        -- ─────────────────────────────────────────────────────────────────
        -- Bash
        -- ─────────────────────────────────────────────────────────────────
        if debugAdapters.bash then
          dap.adapters.bashdb = {
            type = "executable",
            command = debugAdapters.bash,
            name = "bashdb",
          }
          dap.configurations.sh = {
            {
              type = "bashdb",
              request = "launch",
              name = "Launch file",
              showDebugOutput = true,
              pathBashdb = debugAdapters.bashdb or debugAdapters.bash,
              pathBashdbLib = debugAdapters.bashdbLib or "",
              trace = true,
              file = "${file}",
              program = "${file}",
              cwd = "${workspaceFolder}",
              pathCat = "cat",
              pathBash = "/bin/bash",
              pathMkfifo = "mkfifo",
              pathPkill = "pkill",
              args = {},
              env = {},
              terminalKind = "integrated",
            },
          }
        end

        -- ─────────────────────────────────────────────────────────────────
        -- Lua (local-lua-debugger-vscode)
        -- ─────────────────────────────────────────────────────────────────
        if debugAdapters.lua then
          dap.adapters["local-lua"] = {
            type = "executable",
            command = "node",
            args = { debugAdapters.lua },
          }
          dap.configurations.lua = {
            {
              type = "local-lua",
              request = "launch",
              name = "Debug current file",
              cwd = "${workspaceFolder}",
              program = {
                lua = "lua",
                file = "${file}",
              },
            },
          }
        end
      end
    end,
  },

  -- nvim-dap-view
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
              term_restart = {
                render = function(session)
                  local group = session and "ControlTerminate" or "ControlRunLast"
                  local icon = session and "" or ""
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
              short_label = " [B]",
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
              keymap = "K",
              label = "Sessions [K]",
              short_label = " [K]",
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

  -- nvim-dap-ui (disabled, using dap-view instead)
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

  -- mason.nvim integration - DISABLED when using nixCats
  {
    "jay-babu/mason-nvim-dap.nvim",
    enabled = not isNixCats,
    dependencies = "mason.nvim",
    cmd = { "DapInstall", "DapUninstall" },
    opts = {
      automatic_installation = true,
      handlers = {},
      ensure_installed = {},
    },
    config = function() end,
  },
}
