# Canonical MCP server registry — single source of truth.
#
# Consumed by:
#   - modules/common/programs/dev/claude.nix    (Home Manager → Claude Code)
#   - modules/containers/litellm.nix            (NixOS → LiteLLM container image)
#
# Each entry describes the server in both packaging forms so each consumer
# can pick the one native to its runtime.
#
# Fields:
#   mcpServerNix  - package name exposed by natsukium/mcp-servers-nix
#                   (used by Claude Code to invoke the Nix-built binary)
#   runtime       - "npx" | "uvx" — which package manager pre-warms the
#                   container-side install of this server
#   package       - npm or PyPI package name (for the runtime above)
#   args          - default CLI args (optional)
#   env           - environment variables (optional)
{
  filesystem = {
    mcpServerNix = "mcp-server-filesystem";
    runtime = "npx";
    package = "@modelcontextprotocol/server-filesystem";
    args = ["/home/killua"];
  };

  fetch = {
    mcpServerNix = "mcp-server-fetch";
    runtime = "uvx";
    package = "mcp-server-fetch";
  };

  memory = {
    mcpServerNix = "mcp-server-memory";
    runtime = "npx";
    package = "@modelcontextprotocol/server-memory";
    env.MEMORY_FILE_PATH = "/home/killua/.local/share/claude/memory.json";
  };

  sequential-thinking = {
    mcpServerNix = "mcp-server-sequential-thinking";
    runtime = "npx";
    package = "@modelcontextprotocol/server-sequential-thinking";
  };
}
