# Canonical MCP server registry — single source of truth.
#
# Consumed by:
#   - modules/common/programs/dev/claude.nix    (Home Manager → Claude Code)
#   - modules/containers/litellm.nix            (NixOS → LiteLLM container image)
#
# Two entry shapes are supported:
#
# 1) Catalog entry (natsukium/mcp-servers-nix):
#    mcpServerNix  - package name exposed by natsukium/mcp-servers-nix
#                    (used by Claude Code to invoke the Nix-built binary)
#    runtime       - "npx" | "uvx" — pre-warm lane inside the LiteLLM image
#    package       - npm or PyPI package name (for the runtime above)
#    args          - default CLI args (optional)
#    env           - environment variables (optional)
#
# 2) Git-sourced entry (for servers with no PyPI/npm publish):
#    gitSource     - { owner; repo; rev; hash; }  → passed to fetchFromGitHub
#    runtime       - "uv-run" — uv manages a pyproject-based venv at first run
#                    (extend the dispatcher in claude.nix to add pipx/npm variants)
#    entrypoint    - path inside the repo (e.g. "src/main.py")
#    env           - environment variables (optional)
#
#    Git-sourced entries are not pre-warmed by the LiteLLM image (their runtime
#    value doesn't match the "npx"/"uvx" filters there).
#
#    To bump: `git ls-remote <url> HEAD` for the new rev, then
#    `nix-prefetch-github <owner> <repo> --rev <rev>` for the hash.
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

  libreoffice = {
    gitSource = {
      owner = "patrup";
      repo = "mcp-libre";
      rev = "edc5123dcd740049c54de9bc9abf8d69b2f1293f";
      hash = "sha256-J0oXBvn5Bejnn6p6cc4He6lfk+aFnuMSgxJBGhcS6EE=";
    };
    runtime = "uv-run";
    entrypoint = "src/main.py";
  };
}
