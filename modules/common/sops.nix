{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: {
  sops = {
    age.keyFile = "/home/killua/.config/sops/age/keys.txt";
    defaultSopsFile = ../../secrets/personal.yaml;
    secrets = {
      "boeing/git_name" = {};
      "boeing/git_email" = {};
      "boeing/vpn_userid" = {};
      "das/git_name" = {};
      "das/git_email" = {};
      "realdebrid_token" = {};
      "nvidia_api_key" = {};
      "google_studio_key" = {};
      "mistral_api_key" = {};
      "mistral_codestral_api_key" = {};
      "freshrss_admin_api_password" = {};
      "azure/bastion_username" = {};
      "azure/dev_subscription_id" = {};
      "azure/prod_subscription_id" = {};
      "azure/bastion_subscription_id" = {};
      "azure/oracle_host" = {};
      "azure/oracle_port" = {};
      "azure/oracle_username" = {};
      "azure/oracle_password" = {};
      "azure/oracle_vnet_url" = {};
      "azure/pg_db_user" = {};
      "azure/pg_db_pass" = {};
      "azure/pg_vnet_url" = {};
      # Read-only DB creds dedicated to the MCP servers (postgres/cosmos), kept
      # separate from the full-access bastion creds above so an LLM-driven MCP
      # can only read. Postgres: a GRANT-restricted role. Cosmos: the account's
      # read-only primary key (Keys → Read-only Keys in the portal).
      "azure/pg_ro_user" = {};
      "azure/pg_ro_pass" = {};
      "azure/cosmos_ro_key" = {};
      "azure/cosmos_auth_key" = {};
      "azure/cosmos_vnet_url" = {};
      "azure/da_ssh_password" = {};
      # Apify API token for the Content Rewards campaign-scraper MCP
      # (modules/common/programs/dev/ai/apify-mcp.nix). apify.com → Settings →
      # Integrations → API token.
      "apify/token" = {};
      # YouTube clipping MCPs (modules/common/programs/dev/ai/youtube-mcp.nix,
      # youtube-trends-mcp.nix). YouTube Data API v3 key (Google Cloud) +
      # free trendsmcp.ai key (https://www.trendsmcp.ai/account).
      "youtube/data_api_key" = {};
      "trends/api_key" = {};
    };
  };
}
