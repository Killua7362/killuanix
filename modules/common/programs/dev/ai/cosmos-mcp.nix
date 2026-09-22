# Cosmos DB MCP server — robinong79/mcp-cosmos.
#
# The Cosmos analogue of oracle-sqlcl-mcp.nix / postgres-mcp.nix. Talks to a
# Cosmos DB NoSQL (SQL API) account via the @azure/cosmos SDK using
# endpoint + primary-key auth (COSMOSDB_URI / COSMOSDB_KEY) — matching how
# `bastion cosmos` reaches the DAS dev account (primary key, not AAD/RBAC), so
# Microsoft's AAD-only Azure MCP (`@azure/mcp`) is the wrong tool here.
#
# NOT on npm — the upstream ships a TS project you build (`npm install && npm
# run build`). Lazy-built into $XDG_CACHE_HOME on first call (cc-hooks-ts /
# ruflo idiom — no nix hash to maintain); floating HEAD, pin by editing `ref`.
#
# Pairs with `bastion cosmos`. Two non-obvious requirements carried over from
# the bastion-cosmos script banner — the MCP will fail without both:
#   1. SNI/cert: the Cosmos cert is for *.documents.azure.com, so COSMOSDB_URI
#      MUST use the real hostname (below), and you add a loopback hosts entry
#      so the name resolves locally while the tunnel does the real hop:
#          echo "127.0.0.1 bdce-cosmosdb-dev-eastus.documents.azure.com" | sudo tee -a /etc/hosts
#      The URI's :8443 matches `bastion cosmos`'s LOCAL_COSMOS_PORT forward
#      (ssh resolves the -L target on the REMOTE side, so the real gateway is
#      still reached inside the VNet; the hosts entry only steers the client).
#   2. Gateway mode: @azure/cosmos in Node defaults to gateway mode, so every
#      request rides the single endpoint:443 — direct mode's per-partition
#      backend TCP would not exist through the tunnel.
#
# `optional = true` — opt in per-project via
#   claude-kit.nix:mcp = [ "cosmos" ];
# Linux-only: the bastion tunnel it targets is chrollo/killua-only.
{
  pkgs,
  config,
  lib,
  ...
}: let
  # Real account hostname (see requirement 1 above). Not a secret — it's the
  # published dev endpoint used across the domain.yaml files. :8443 = the
  # bastion-cosmos LOCAL_COSMOS_PORT forward.
  cosmosUri = "https://bdce-cosmosdb-dev-eastus.documents.azure.com:8443";
  ref = "main";

  cosmosMcpWrapper = pkgs.writeShellApplication {
    name = "mcp-cosmos";
    runtimeInputs = [pkgs.nodejs pkgs.git];
    text = ''
      cache="''${XDG_CACHE_HOME:-$HOME/.cache}/mcp-cosmos/${ref}"
      if [ ! -e "$cache/dist/index.js" ]; then
        rm -rf "$cache"
        git clone --depth 1 --branch "${ref}" https://github.com/robinong79/mcp-cosmos "$cache"
        (cd "$cache" && npm install --no-audit --no-fund && npm run build)
      fi
      # COSMOSDB_KEY carries the primary key — source it from the sops-rendered
      # env file so it never lands in the nix store or process argv.
      set -a
      # shellcheck disable=SC1091
      . "${config.sops.templates."cosmos-mcp.env".path}"
      set +a
      exec node "$cache/dist/index.js" "$@"
    '';
  };
in {
  config = lib.mkIf pkgs.stdenv.isLinux {
    # Read-only by design: uses the account's read-only primary key
    # (azure/cosmos_ro_key — portal: Keys → Read-only Keys), NOT the full
    # master key (azure/cosmos_auth_key, which bastion cosmos uses). Cosmos
    # enforces read-only server-side, so even if the MCP exposes write tools
    # they fail with 403.
    sops.templates."cosmos-mcp.env".content = ''
      COSMOSDB_URI=${cosmosUri}
      COSMOSDB_KEY=${config.sops.placeholder."azure/cosmos_ro_key"}
    '';

    local.extraMcpServers.cosmos = {
      command = lib.getExe cosmosMcpWrapper;
      optional = true;
    };
  };
}
