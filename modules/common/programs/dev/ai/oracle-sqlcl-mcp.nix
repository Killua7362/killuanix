{
  pkgs,
  lib,
  ...
}: let
  # SQLcl 25.1+ ships an MCP server built into the launcher itself — `sqlcl
  # -mcp` reads JSON-RPC on stdin and exposes the user's saved connections
  # (~/.dbtools/connections.json) as MCP tools. There is no separate npm
  # package; the wrapper just invokes sqlcl directly.
  #
  # nixpkgs renames the launcher to `sqlcl` (avoids clash with GNU
  # parallel's `sql`) — pkgs.sqlcl bundles its own JRE so no extra Java
  # setup is needed.
  sqlclMcpWrapper = pkgs.writeShellApplication {
    name = "mcp-oracle-sqlcl";
    runtimeInputs = [pkgs.sqlcl];
    text = ''
      exec sqlcl -mcp "$@"
    '';
  };
in {
  # Oracle MCP Server for SQLcl. The MCP server is built into SQLcl >=25.1
  # itself, started via the `-mcp` flag — no separate package or runtime.
  #
  # Lives here (not modules/common/mcp-servers.nix) so the wrapper can pin
  # the exact pkgs.sqlcl store path on the command line. Registers via the
  # `local.extraMcpServers` side-channel declared in claude.nix — same
  # pattern as code-index.nix / kindly-web-search.nix.
  #
  # `optional = true` keeps it out of the global mcpServers list so it only
  # loads in projects that opt in via
  #   claude-kit.nix:mcp = [ "oracle-sqlcl" ];
  # (or `claude-kit lazy add mcp oracle-sqlcl` outside a den project).
  #
  # Prerequisites the user owns (not nix-managed):
  #   1. Create a saved SQLcl connection that points at the bastion-sql
  #      tunnel. nixpkgs renames the launcher to `sqlcl` (avoids clash with
  #      GNU parallel's `sql`); use that name from the user shell:
  #        sqlcl /nolog
  #        SQL> connect -save beastg1 -savepwd ${user}/${pass}@127.0.0.1:1521/beastg1
  #      (Bastion tunnel must be up: `BASTION_SSH_VIA_SOCKS=1 bastion-sql dev`.)
  #   2. Connection name (`beastg1` in the example) is the handle the MCP
  #      tools accept. SERVICE_NAME switches stages — re-use the same
  #      connection name with different service names if needed.
  local.extraMcpServers.oracle-sqlcl = {
    command = lib.getExe sqlclMcpWrapper;
    optional = true;
  };
}
