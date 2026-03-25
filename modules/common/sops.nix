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
      "realdebrid_token" = {};
      "nvidia_api_key" = {};
      "google_studio_key" = {};
      "mistral_api_key" = {};
      "mistral_codestral_api_key" = {};
      "qdrant_api_key" = {};
      "qdrant_cluster_endpoint" = {};
    };
  };
}
