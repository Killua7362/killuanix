# Azure Bastion tooling for DigitalAviations STG access.
#
# Installs azure-cli (with the ssh + bastion extensions) plus the DB clients
# used against the bastion tunnels. The bastion helper scripts themselves are
# NOT built here — they live in the DotFiles submodule under
# `DotFiles/scripts/boeing/`, fronted by a single `bastion` dispatcher on PATH
# (`bastion ssh|sql|login|pg|cosmos`). They read secrets from ONE env file at
# `~/.config/azure-bastion.env` (override `$BASTION_ENV_FILE`) so they run on
# any Linux. This module's nix-specific jobs:
#   1. put their runtime deps (az, proxychains, ssh) on PATH, and
#   2. render that env file from the sops `azure/*` secrets via sops.templates
#      (so a plain `nix_switch` populates it; no per-key file reads at runtime).
#
# Imported only by the NixOS hosts that need it (chrollo + killua).
{
  config,
  pkgs,
  lib,
  ...
}: let
  azCli = pkgs.azure-cli.withExtensions [
    pkgs.azure-cli.extensions.ssh
    pkgs.azure-cli.extensions.bastion
  ];

  sqldeveloper = pkgs.callPackage ../../../../../packages/sqldeveloper/package.nix {};
in {
  config = lib.mkIf pkgs.stdenv.isLinux {
    # Runtime deps for the DotFiles/scripts/boeing bastion scripts.
    home.packages = [
      azCli
      pkgs.proxychains-ng # bastion SOCKS routing (BASTION_SSH_VIA_SOCKS=1)
      pkgs.openssh # bastion sql/pg/cosmos: ssh -L over the bastion tunnel
      sqldeveloper
      pkgs.jetbrains.datagrip
      pkgs.sqlcl
      pkgs.azure-storage-azcopy
    ];

    # Compose the individual azure/* sops secrets into the single env file the
    # bastion scripts source. Rendered at HM activation to the path below with
    # mode 0400. On non-nix hosts, hand-create this file instead (see
    # DotFiles/scripts/boeing/bastion.d/azure-bastion.env.example).
    sops.templates."azure-bastion.env" = {
      content = ''
        AZURE_BASTION_USERNAME=${config.sops.placeholder."azure/bastion_username"}
        AZURE_DEV_SUBSCRIPTION_ID=${config.sops.placeholder."azure/dev_subscription_id"}
        AZURE_PROD_SUBSCRIPTION_ID=${config.sops.placeholder."azure/prod_subscription_id"}
        AZURE_BASTION_SUBSCRIPTION_ID=${config.sops.placeholder."azure/bastion_subscription_id"}
        AZURE_ORACLE_HOST=${config.sops.placeholder."azure/oracle_host"}
        AZURE_ORACLE_PORT=${config.sops.placeholder."azure/oracle_port"}
        AZURE_ORACLE_USERNAME=${config.sops.placeholder."azure/oracle_username"}
      '';
      path = "${config.home.homeDirectory}/.config/azure-bastion.env";
    };

    # Default ON: every `bastion` invocation routes az through the boeingvpn-ui
    # SOCKS5 listener via proxychains-ng. Override per-call with
    # `BASTION_SSH_VIA_SOCKS= bastion ssh ...` (empty value) if the tunnel isn't
    # up and you want to try direct.
    home.sessionVariables.BASTION_SSH_VIA_SOCKS = "1";
  };
}
