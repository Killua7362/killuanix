return {
  {
  "olimorris/codecompanion.nvim",
    config = function()

      require("codecompanion").setup({
      ---@module "codecompanion"
      ---@type CodeCompanion.Config
        display = {
          action_palette = {
            width = 95,
            height = 10,
            prompt = "Prompt ", -- Prompt used for interactive LLM calls
            provider = "snacks", -- Can be "default", "telescope", "fzf_lua", "mini_pick" or "snacks". If not specified, the plugin will autodetect installed providers.
            opts = {
              show_default_actions = true, -- Show the default actions in the action palette?
              show_default_prompt_library = true, -- Show the default prompt library in the action palette?
              title = "CodeCompanion actions", -- The title of the action palette
            },
          },
        },
        strategies = {
          chat = {
            adapter = "deepseek-v3.1",
            tools = {
              opts = {
                default_tools = {
                  -- "insert_edit_into_file"
                }
              }
            }
          },
          inline = {
            adapter = "deepseek-v3.1",
          },
        },
        extensions = {
          mcphub = {
            callback = "mcphub.extensions.codecompanion",
            opts = {
              make_vars = true,
              make_slash_commands = true,
              show_result_in_chat = true
            }
          },
          history = {
              enabled = true,
              opts = {
                  -- Keymap to open history from chat buffer (default: gh)
                  keymap = "gh",
                  -- Keymap to save the current chat manually (when auto_save is disabled)
                  save_chat_keymap = "sc",
                  -- Save all chats by default (disable to save only manually using 'sc')
                  auto_save = true,
                  -- Number of days after which chats are automatically deleted (0 to disable)
                  expiration_days = 0,
                  -- Picker interface (auto resolved to a valid picker)
                  picker = "telescope", --- ("telescope", "snacks", "fzf-lua", or "default") 
                  ---Optional filter function to control which chats are shown when browsing
                  chat_filter = nil, -- function(chat_data) return boolean end
                  -- Customize picker keymaps (optional)
                  picker_keymaps = {
                      rename = { n = "r", i = "<M-r>" },
                      delete = { n = "d", i = "<M-d>" },
                      duplicate = { n = "<C-y>", i = "<C-y>" },
                  },
                  ---Automatically generate titles for new chats
                  auto_generate_title = true,
                  title_generation_opts = {
                      ---Adapter for generating titles (defaults to current chat adapter) 
                      adapter = nil, -- "copilot"
                      ---Model for generating titles (defaults to current chat model)
                      model = nil, -- "gpt-4o"
                      ---Number of user prompts after which to refresh the title (0 to disable)
                      refresh_every_n_prompts = 0, -- e.g., 3 to refresh after every 3rd user prompt
                      ---Maximum number of times to refresh the title (default: 3)
                      max_refreshes = 3,
                      format_title = function(original_title)
                          -- this can be a custom function that applies some custom
                          -- formatting to the title.
                          return original_title
                      end
                  },
                  ---On exiting and entering neovim, loads the last chat on opening chat
                  continue_last_chat = false,
                  ---When chat is cleared with `gx` delete the chat from history
                  delete_on_clearing_chat = false,
                  ---Directory path to save the chats
                  dir_to_save = vim.fn.stdpath("data") .. "/codecompanion-history",
                  ---Enable detailed logging for history extension
                  enable_logging = false,

                  -- Summary system
                  summary = {
                      -- Keymap to generate summary for current chat (default: "gcs")
                      create_summary_keymap = "gcs",
                      -- Keymap to browse summaries (default: "gbs")
                      browse_summaries_keymap = "gbs",
                      
                      generation_opts = {
                          adapter = nil, -- defaults to current chat adapter
                          model = nil, -- defaults to current chat model
                          context_size = 90000, -- max tokens that the model supports
                          include_references = true, -- include slash command content
                          include_tool_outputs = true, -- include tool execution results
                          system_prompt = nil, -- custom system prompt (string or function)
                          format_summary = nil, -- custom function to format generated summary e.g to remove <think/> tags from summary
                      },
                  },
                  
                  -- Memory system (requires VectorCode CLI)
                  memory = {
                      -- Automatically index summaries when they are generated
                      auto_create_memories_on_summary_generation = true,
                      -- Path to the VectorCode executable
                      vectorcode_exe = "vectorcode",
                      -- Tool configuration
                      tool_opts = { 
                          -- Default number of memories to retrieve
                          default_num = 10 
                      },
                      -- Enable notifications for indexing progress
                      notify = true,
                      -- Index all existing memories on startup
                      -- (requires VectorCode 0.6.12+ for efficient incremental indexing)
                      index_on_startup = false,
                  },
              }
          }
        },
        opts = {
          log_level = "DEBUG"
        },
        adapters = {
          acp = {

          },
          http = {
          ["deepseek-v3.1"] = function()
            return require("codecompanion.adapters").extend("openai_compatible", {
              env = {
                url = "https://llm.chutes.ai",
                api_key = "CHUTES_API_KEY",
                chat_url = "/v1/chat/completions",
              },
              schema = {
                model = {
                  default = "deepseek-ai/DeepSeek-V3.1",
                },
              },
            })
          end,
          ["deepseek-v3.1-terminus"] = function()
            return require("codecompanion.adapters").extend("openai_compatible", {
              env = {
                url = "https://llm.chutes.ai",
                api_key = "CHUTES_API_KEY",
                chat_url = "/v1/chat/completions",
              },
              schema = {
                model = {
                  default = "deepseek-ai/DeepSeek-V3.1-Terminus",
                },
              },
            })
          end,
          ["deepseek-v3.2-exp"] = function()
            return require("codecompanion.adapters").extend("openai_compatible", {
              env = {
                url = "https://llm.chutes.ai",
                api_key = "CHUTES_API_KEY",
                chat_url = "/v1/chat/completions",
              },
              schema = {
                model = {
                  default = "deepseek-ai/DeepSeek-V3.2-Exp",
                },
              },
            })
          end,
          ["deepseek-chimera"] = function()
            return require("codecompanion.adapters").extend("openai_compatible", {
              env = {
                url = "https://llm.chutes.ai",
                api_key = "CHUTES_API_KEY",
                chat_url = "/v1/chat/completions",
              },
              schema = {
                model = {
                  default = "tngtech/DeepSeek-TNG-R1T2-Chimera",
                },
              },
            })
          end,
          ["deepseek-r1-0528"] = function()
            return require("codecompanion.adapters").extend("openai_compatible", {
              env = {
                url = "https://llm.chutes.ai",
                api_key = "CHUTES_API_KEY",
                chat_url = "/v1/chat/completions",
              },
              schema = {
                model = {
                  default = "deepseek-ai/DeepSeek-R1-0528",
                },
              },
            })
          end,
          ["qwen-coder"] = function()
            return require("codecompanion.adapters").extend("openai_compatible", {
              env = {
                url = "https://llm.chutes.ai",
                api_key = "CHUTES_API_KEY",
                chat_url = "/v1/chat/completions",
              },
              schema = {
                model = {
                  default = "Qwen/Qwen3-Coder-480B-A35B-Instruct-FP8",
                },
              },
            })
          end,
          ["kimi-K2-thinking"] = function()
            return require("codecompanion.adapters").extend("openai_compatible", {
              env = {
                url = "https://llm.chutes.ai",
                api_key = "CHUTES_API_KEY",
                chat_url = "/v1/chat/completions",
              },
              schema = {
                model = {
                  default = "moonshotai/Kimi-K2-Thinking",
                },
              },
            })
          end,
          ["kimi-K2-instruct"] = function()
            return require("codecompanion.adapters").extend("openai_compatible", {
              env = {
                url = "https://llm.chutes.ai",
                api_key = "CHUTES_API_KEY",
                chat_url = "/v1/chat/completions",
              },
              schema = {
                model = {
                  default = "moonshotai/Kimi-K2-Instruct-0905",
                },
              },
            })
          end,
          ["glm-4.6"] = function()
            return require("codecompanion.adapters").extend("openai_compatible", {
              env = {
                url = "https://llm.chutes.ai",
                api_key = "CHUTES_API_KEY",
                chat_url = "/v1/chat/completions",
              },
              schema = {
                model = {
                  default = "zai-org/GLM-4.6",
                },
              },
            })
          end,
          }
        },
      })

      vim.keymap.set({ "n", "v" }, "<leader>ck", "<cmd>CodeCompanionActions<cr>", { noremap = true, silent = true })
      vim.keymap.set(
        { "n", "v" },
        "<C-,>",
        "<cmd>CodeCompanionChat Toggle<cr>",
        { noremap = true, silent = true }
      )
      vim.keymap.set("v", "ga", "<cmd>CodeCompanionChat Add<cr>", { noremap = true, silent = true })

      -- Expand 'cc' into 'CodeCompanion' in the command line
      vim.cmd([[cab cc CodeCompanion]])
    end,

    dependencies = {
      "ravitemer/codecompanion-history.nvim",
      {
        "j-hui/fidget.nvim",
        opts = {
          -- options
        },
      },
      {
        "nvim-mini/mini.diff",
        config = function()
          local diff = require("mini.diff")
          diff.setup({
            -- Disabled by default
            source = diff.gen_source.none(),
          })
        end,
      },
      "nvim-lua/plenary.nvim",
      "ravitemer/mcphub.nvim",
{
  "OXY2DEV/markview.nvim",
  lazy = false,
  opts = {
    preview = {
      filetypes = { "markdown", "codecompanion" },
      ignore_buftypes = {},
    },
  },
},
      {
        "HakonHarnes/img-clip.nvim",
        opts = {
          filetypes = {
            codecompanion = {
              prompt_for_file_name = false,
              template = "[Image]($FILE_PATH)",
              use_absolute_path = true,
            },
          },
        },
      },
    },
    init = function()
      require("config.companion-notif"):init()
    end,
  },
  {
    "saghen/blink.cmp",
    optional = true,
    opts = {
      sources = {
        per_filetype = {
          codecompanion = { "codecompanion" },
        }
      },
    },
  }
}
