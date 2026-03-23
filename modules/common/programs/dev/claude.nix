{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  cfg = config.programs.claude-code;

  mcpServerType = lib.types.submodule {
    options = {
      command = lib.mkOption {
        type = lib.types.str;
        description = "Command to run the MCP server.";
      };
      args = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Arguments to pass to the MCP server command.";
      };
      env = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        description = "Environment variables for the MCP server.";
      };
    };
  };

  # Build the settings.json content
  settingsContent = lib.filterAttrs (_: v: v != null && v != {} && v != []) ({
    permissions = lib.optionalAttrs (cfg.allowedTools != []) {
      allow = cfg.allowedTools;
    } // lib.optionalAttrs (cfg.deniedTools != []) {
      deny = cfg.deniedTools;
    };
  } // lib.optionalAttrs (cfg.mcpServers != {}) {
    mcpServers = lib.mapAttrs (_: server:
      lib.filterAttrs (_: v: v != [] && v != {}) {
        command = server.command;
        args = server.args;
        env = server.env;
      }
    ) cfg.mcpServers;
  } // cfg.extraSettings);

in
{
  options.programs.claude-code = {
    mcpServers = lib.mkOption {
      type = lib.types.attrsOf mcpServerType;
      default = {};
      description = "MCP servers to configure as plugins for Claude Code.";
      example = lib.literalExpression ''
        {
          filesystem = {
            command = "npx";
            args = [ "-y" "@modelcontextprotocol/server-filesystem" "/home/user/projects" ];
          };
          github = {
            command = "npx";
            args = [ "-y" "@modelcontextprotocol/server-github" ];
            env = {
              GITHUB_PERSONAL_ACCESS_TOKEN = "your-token";
            };
          };
        }
      '';
    };

    allowedTools = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "List of tools to allow without prompting.";
      example = [ "Bash(git *)" "mcp__filesystem__read_file" ];
    };

    deniedTools = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "List of tools to deny.";
    };

    extraSettings = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Extra settings to merge into settings.json.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.file.".claude/settings.json" = lib.mkIf (settingsContent != {}) {
      text = builtins.toJSON settingsContent;
    };
  };
}
