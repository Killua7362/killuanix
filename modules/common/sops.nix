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
      "das/git_name" = {};
      "das/git_email" = {};
      "realdebrid_token" = {};
      "nvidia_api_key" = {};
      "google_studio_key" = {};
      "mistral_api_key" = {};
      "mistral_codestral_api_key" = {};
      "qdrant_api_key" = {};
      "qdrant_cluster_endpoint" = {};
      "freshrss_admin_api_password" = {};
      "azure/bastion_username" = {};
      "azure/dev_subscription_id" = {};
      "azure/prod_subscription_id" = {};
      "azure/bastion_subscription_id" = {};
      "azure/oracle_host" = {};
      "azure/oracle_port" = {};
      "azure/oracle_username" = {};
      "azure/oracle_password" = {};
    };
  };
}
