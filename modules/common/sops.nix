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
    };
  };
}
