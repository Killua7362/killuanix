local java_filetypes = { "java" }

-- Check if we're in a nixCats environment
local is_nixcats = false
local nixcats_paths = {}

local ok, nixCatsUtils = pcall(require, 'nixCatsUtils')
if ok then
  is_nixcats = nixCatsUtils.isNixCats
  if is_nixcats then
    local nixCats = require('nixCats')
    nixcats_paths = {
      jdtls = nixCats('extra.jdtls') or "",
      lombok = nixCats('extra.lombok') or "",
      java_debug_adapter = nixCats('extra.java_debug_adapter') or "",
      java_test = nixCats('extra.java_test') or "",
    }
  end
end

-- Utility function to extend or override a config table, similar to the way
-- that Plugin.opts works.
---@param config table
---@param custom function | table | nil
local function extend_or_override(config, custom, ...)
  if type(custom) == "function" then
    config = custom(config, ...) or config
  elseif custom then
    config = vim.tbl_deep_extend("force", config, custom) --[[@as table]]
  end
  return config
end

return {
  recommended = function()
    return LazyVim.extras.wants({
      ft = "java",
      root = {
        "build.gradle",
        "build.gradle.kts",
        "build.xml", -- Ant
        "pom.xml", -- Maven
        "settings.gradle", -- Gradle
        "settings.gradle.kts", -- Gradle
      },
    })
  end,

  -- Ensure java debugger and test packages are installed.
  {
    "mfussenegger/nvim-dap",
    optional = true,
    opts = function()
      local dap = require("dap")
      dap.configurations.java = {
        {
          type = "java",
          request = "attach",
          name = "Debug (Attach) - Remote",
          hostName = "127.0.0.1",
          port = 5005,
        },
      }
    end,
  },

  -- Configure nvim-lspconfig to install the server automatically via mason, but
  -- defer actually starting it to our configuration of nvim-jtdls below.
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        jdtls = {},
      },
      setup = {
        jdtls = function()
          return true -- avoid duplicate servers
        end,
      },
    },
  },

  -- Set up nvim-jdtls to attach to java files.
  {
    "mfussenegger/nvim-jdtls",
    dependencies = { "folke/which-key.nvim" },
    ft = java_filetypes,
    opts = function()
      local cmd = { vim.fn.exepath("jdtls") }

      -- Add lombok jar argument
      if is_nixcats then
        if nixcats_paths.lombok and nixcats_paths.lombok ~= "" then
          table.insert(cmd, string.format("--jvm-arg=-javaagent:%s", nixcats_paths.lombok))
        end
      elseif LazyVim.has("mason.nvim") then
        local lombok_jar = vim.fn.expand("$MASON/share/jdtls/lombok.jar")
        table.insert(cmd, string.format("--jvm-arg=-javaagent:%s", lombok_jar))
      end

      return {
        root_dir = function(path)
          return vim.fs.root(path, vim.lsp.config.jdtls.root_markers)
        end,

        project_name = function(root_dir)
          return root_dir and vim.fs.basename(root_dir)
        end,

        jdtls_config_dir = function(project_name)
          return vim.fn.stdpath("cache") .. "/jdtls/" .. project_name .. "/config"
        end,

        jdtls_workspace_dir = function(project_name)
          return vim.fn.stdpath("cache") .. "/jdtls/" .. project_name .. "/workspace"
        end,

        cmd = cmd,

        full_cmd = function(opts)
          local fname = vim.api.nvim_buf_get_name(0)
          local root_dir = opts.root_dir(fname)
          local project_name = opts.project_name(root_dir)
          local cmd = vim.deepcopy(opts.cmd)

          -- Determine jdtls path based on environment
          local jdtls_path
          if is_nixcats then
            jdtls_path = nixcats_paths.jdtls
          else
            jdtls_path = vim.fn.stdpath("data") .. "/mason/packages/jdtls"
          end

          local launcher = vim.fn.glob(jdtls_path .. "/plugins/org.eclipse.equinox.launcher_*.jar")

          if project_name then
            vim.list_extend(cmd, {
              "-Declipse.application=org.eclipse.jdt.ls.core.id1",
              "-Dosgi.bundles.defaultStartLevel=4",
              "-Declipse.product=org.eclipse.jdt.ls.core.product",
              "-Dlog.protocol=true",
              "-Dlog.level=ALL",
              "-Xmx1g",
              "--add-modules=ALL-SYSTEM",
              "--add-opens",
              "java.base/java.util=ALL-UNNAMED",
              "--add-opens",
              "java.base/java.lang=ALL-UNNAMED",
              "-jar",
              launcher,
              "-configuration",
              opts.jdtls_config_dir(project_name),
              "-data",
              opts.jdtls_workspace_dir(project_name),
            })
          end
          return cmd
        end,

        dap = { hotcodereplace = "auto", config_overrides = {} },
        dap_main = {},
        test = true,
        settings = {
          java = {
            configuration = {
              runtimes = {
                {
                  name = "JavaSE-21",
                  path = "/usr/lib/jvm/java-21-openjdk",
                  default = true,
                },
              },
              updateBuildConfiguration = "interactive",
            },
            inlayHints = {
              parameterNames = {
                enabled = "all",
              },
            },
          },
        },
      }
    end,

    config = function(_, opts)
      local bundles = {} ---@type string[]

      -- Helper function to check if dap packages are available
      local function has_dap_packages()
        if is_nixcats then
          return nixcats_paths.java_debug_adapter and nixcats_paths.java_debug_adapter ~= ""
        else
          if LazyVim.has("mason.nvim") then
            local mason_registry = require("mason-registry")
            return mason_registry.is_installed("java-debug-adapter")
          end
        end
        return false
      end

      local function has_test_packages()
        if is_nixcats then
          return nixcats_paths.java_test and nixcats_paths.java_test ~= ""
        else
          if LazyVim.has("mason.nvim") then
            local mason_registry = require("mason-registry")
            return mason_registry.is_installed("java-test")
          end
        end
        return false
      end

      -- Load debug adapter bundles
      if opts.dap and LazyVim.has("nvim-dap") and has_dap_packages() then
        local debug_adapter_path
        if is_nixcats then
          debug_adapter_path = nixcats_paths.java_debug_adapter .. "/server/com.microsoft.java.debug.plugin-*.jar"
        else
          debug_adapter_path = vim.fn.expand("~/.local/share/nvim/mason/packages/java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-*.jar")
        end

        bundles = vim.fn.glob(debug_adapter_path, false, true)

        -- Load java-test bundles
        if opts.test and has_test_packages() then
          local java_test_path
          if is_nixcats then
            java_test_path = nixcats_paths.java_test .. "/server/*.jar"
          else
            java_test_path = vim.fn.expand("~/.local/share/nvim/mason/packages/java-test/extension/server/*.jar")
          end

          local java_test_bundles = vim.fn.glob(java_test_path, false, true)
          local excluded_patterns = { "jacocoagent", "runner%-jar%-with%-dependencies" }

          for _, java_test_jar in ipairs(java_test_bundles) do
            local fname = vim.fn.fnamemodify(java_test_jar, ":t")
            local exclude = false
            for _, pat in ipairs(excluded_patterns) do
              if fname:match(pat) then
                exclude = true
                break
              end
            end
            if not exclude then
              table.insert(bundles, java_test_jar)
            end
          end
        end
      end

      local function attach_jdtls()
        local fname = vim.api.nvim_buf_get_name(0)

        local config = extend_or_override({
          cmd = opts.full_cmd(opts),
          root_dir = opts.root_dir(fname),
          init_options = {
            bundles = bundles,
          },
          settings = opts.settings,
          capabilities = LazyVim.has("blink.cmp") and require("blink.cmp").get_lsp_capabilities()
            or LazyVim.has("cmp-nvim-lsp") and require("cmp_nvim_lsp").default_capabilities()
            or nil,
        }, opts.jdtls)

        require("jdtls").start_or_attach(config)
      end

      vim.api.nvim_create_autocmd("FileType", {
        pattern = java_filetypes,
        callback = attach_jdtls,
      })

      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if client then
            client.server_capabilities.semanticTokensProvider = nil
          end
        end,
      })

      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if client and client.name == "jdtls" then
            local wk = require("which-key")
            wk.add({
              {
                mode = "n",
                buffer = args.buf,
                { "<leader>cx", group = "extract" },
                { "<leader>cxv", require("jdtls").extract_variable_all, desc = "Extract Variable" },
                { "<leader>cxc", require("jdtls").extract_constant, desc = "Extract Constant" },
                { "<leader>cgs", require("jdtls").super_implementation, desc = "Goto Super" },
                { "<leader>cgS", require("jdtls.tests").goto_subjects, desc = "Goto Subjects" },
                { "<leader>co", require("jdtls").organize_imports, desc = "Organize Imports" },
              },
            })
            wk.add({
              {
                mode = "x",
                buffer = args.buf,
                { "<leader>cx", group = "extract" },
                { "<leader>cxm", [[<ESC><CMD>lua require('jdtls').extract_method(true)<CR>]], desc = "Extract Method" },
                { "<leader>cxv", [[<ESC><CMD>lua require('jdtls').extract_variable_all(true)<CR>]], desc = "Extract Variable" },
                { "<leader>cxc", [[<ESC><CMD>lua require('jdtls').extract_constant(true)<CR>]], desc = "Extract Constant" },
              },
            })

            -- Setup DAP if available
            if opts.dap and LazyVim.has("nvim-dap") and has_dap_packages() then
              require("jdtls").setup_dap(opts.dap)
              if opts.dap_main then
                require("jdtls.dap").setup_dap_main_class_configs(opts.dap_main)
              end

              if opts.test and has_test_packages() then
                wk.add({
                  {
                    mode = "n",
                    buffer = args.buf,
                    { "<leader>t", group = "test" },
                    {
                      "<leader>tt",
                      function()
                        require("jdtls.dap").test_class({
                          config_overrides = type(opts.test) ~= "boolean" and opts.test.config_overrides or nil,
                        })
                      end,
                      desc = "Run All Test",
                    },
                    {
                      "<leader>tr",
                      function()
                        require("jdtls.dap").test_nearest_method({
                          config_overrides = type(opts.test) ~= "boolean" and opts.test.config_overrides or nil,
                        })
                      end,
                      desc = "Run Nearest Test",
                    },
                    { "<leader>tT", require("jdtls.dap").pick_test, desc = "Run Test" },
                  },
                })
              end
            end

            if opts.on_attach then
              opts.on_attach(args)
            end
          end
        end,
      })

      attach_jdtls()
    end,
  },
}
