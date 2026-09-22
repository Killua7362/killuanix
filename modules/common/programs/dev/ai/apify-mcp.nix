# Apify Actors MCP server — scoped to the Whop / Content Rewards campaign
# scraper actor(s).
#
# Exposes an Apify Actor as an MCP tool so Claude can discover live Content
# Rewards clipping/UGC campaigns (rate per 1K views, budget left, creator
# count, category) and filter them in one call, e.g.
#   "active gaming clipping campaigns paying >= $2/1K, >= $10k budget left".
#
# Runtime: the official `@apify/actors-mcp-server` npm package, resolved lazily
# via `npx --yes` on first call (ruflo/cc-hooks-ts idiom — no nix hash to
# maintain). `--actors` pins which Actor(s) are surfaced; comma-separate to add
# more (all three known Content Rewards scrapers listed below).
#
# Auth: Apify requires APIFY_TOKEN (apify.com → Settings → Integrations → API
# token). It's a secret, so it rides a sops-rendered env file (never the nix
# store / process argv) — mirrors postgres-mcp.nix / cosmos-mcp.nix. Add the
# value to secrets/personal.yaml under `apify/token` before switching; without
# it the server starts but every Actor call 401s.
#
# `optional = true` — NOT loaded globally. Opt in per-project via
#   claude-kit.nix:mcp = [ "content-rewards" ];
# (or `claude-kit lazy add mcp content-rewards` outside a den project).
#
# NB: Apify Actors are pay-per-run — each campaign-discovery call consumes
# Apify platform credits on your account.
{
  pkgs,
  config,
  lib,
  ...
}: let
  # Which Apify Actor(s) to surface. Default: the automation-lab Content
  # Rewards scraper. Alternatives (comma-separate to add):
  #   fayoussef/whop-clipping-campaigns-scraper
  #   tactful_anvil/whop-content-rewards-scraper
  actors = "automation-lab/whop-content-rewards-scraper";

  apifyMcpWrapper = pkgs.writeShellApplication {
    name = "mcp-apify-content-rewards";
    runtimeInputs = [pkgs.nodejs];
    text = ''
      # APIFY_TOKEN comes from the sops-rendered env file so the secret never
      # lands in the nix store or on the command line.
      set -a
      # shellcheck disable=SC1091
      . "${config.sops.templates."apify-mcp.env".path}"
      set +a
      exec npx --yes @apify/actors-mcp-server --actors "${actors}" "$@"
    '';
  };
in {
  sops.templates."apify-mcp.env".content = ''
    APIFY_TOKEN=${config.sops.placeholder."apify/token"}
  '';

  local.extraMcpServers.content-rewards = {
    command = lib.getExe apifyMcpWrapper;
    optional = true;
  };
}
