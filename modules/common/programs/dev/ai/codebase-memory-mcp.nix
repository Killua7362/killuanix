{
  pkgs,
  lib,
  ...
}: let
  # DeusData/codebase-memory-mcp — code-intelligence knowledge graph MCP.
  #
  # Uses the **UI-enabled release binary** at ~/.local/bin/codebase-memory-mcp
  # (installed per upstream install.sh's --ui variant: the ui-linux-amd64-portable
  # asset, a fully-static binary). The npm package ships WITHOUT the embedded UI
  # ("built without the embedded UI, HTTP server will not start"), so we can't use
  # the npxDirect registry shape for the UI. `--ui=true` serves the graph
  # visualization at http://localhost:9749.
  #
  # `auto_index = true` is set out-of-band via `codebase-memory-mcp config set`
  # (persisted config). The graph store lives in ~/.cache/codebase-memory-mcp and
  # is shared regardless of how the binary is launched (npm or this binary), so
  # the existing index carries over (same v0.8.1).
  #
  # Wrapper (serena-style) so only `command` is needed in extraMcpServers. The
  # ~/.local/bin binary is NOT nix-managed — reinstall via upstream install.sh
  # (`curl -fsSL …/install.sh | bash -s -- --ui`) if it goes missing.
  cbmWrapper = pkgs.writeShellApplication {
    name = "mcp-codebase-memory-mcp";
    text = ''
      # Persist server stderr (panics/errors) — Claude Code discards the MCP
      # subprocess's stderr, so silent crashes leave no trace. Tee to a log while
      # still forwarding to fd 2 so Claude's transport sees it unchanged.
      mkdir -p "$HOME/.cache/codebase-memory-mcp"
      exec "$HOME/.local/bin/codebase-memory-mcp" --ui=true "$@" \
        2> >(tee -a "$HOME/.cache/codebase-memory-mcp/server.log" >&2)
    '';
  };
in {
  # Registered via the local.extraMcpServers side-channel (same pattern as
  # oracle-sqlcl-mcp.nix / serena-mcp.nix). optional = true keeps it out of the
  # global wiring; opt in per-project via claude-kit.nix:mcp = [ "codebase-memory-mcp" ].
  local.extraMcpServers.codebase-memory-mcp = {
    command = lib.getExe cbmWrapper;
    optional = true;
  };
}
