# Azure Bastion SSH wrapper for DigitalAviations STG access.
#
# Installs azure-cli with the `ssh` extension and a `bastion-ssh` wrapper
# script. The wrapper reads the DigitalAviations username from a sops
# secret at `azure/bastion_username` so the runbook's "replace line 79"
# step is handled at activation, not by editing a checked-in file.
#
# Imported only by the NixOS hosts that need it (chrollo + killua).
{
  config,
  pkgs,
  lib,
  ...
}: let
  secretPath = name: config.sops.secrets.${name}.path;

  usernameFile = secretPath "azure/bastion_username";
  devSubFile = secretPath "azure/dev_subscription_id";
  prodSubFile = secretPath "azure/prod_subscription_id";
  bastionSubFile = secretPath "azure/bastion_subscription_id";
  oracleHostFile = secretPath "azure/oracle_host";
  oraclePortFile = secretPath "azure/oracle_port";
  oracleUserFile = secretPath "azure/oracle_username";
  oraclePassFile = secretPath "azure/oracle_password";

  azCli = pkgs.azure-cli.withExtensions [
    pkgs.azure-cli.extensions.ssh
    pkgs.azure-cli.extensions.bastion
  ];

  sqldeveloper = pkgs.callPackage ../../../../../packages/sqldeveloper/package.nix {};

  # SOCKS5 proxy config for proxychains-ng. Points at the boeingvpn-ui
  # ocproxy listener on 127.0.0.1:1080 — see
  # modules/common/programs/boeingvpn-ui/daemon.py.
  proxychainsConf = pkgs.writeText "bastion-ssh.proxychains.conf" ''
    strict_chain
    proxy_dns
    remote_dns_subnet 224
    tcp_read_time_out 15000
    tcp_connect_time_out 8000
    # Don't SOCKS-route loopback. az spawns a local ssh client that
    # connects to 127.0.0.1:<auto-port> to enter the bastion tunnel;
    # LD_PRELOAD inherits into the child, so without this rule
    # proxychains tries to send the ssh→localhost connect through
    # ocproxy and gets "Connection refused" instead of the local listener.
    localnet 127.0.0.0/255.0.0.0
    [ProxyList]
    socks5 127.0.0.1 1080
  '';

  bastionSshScript = pkgs.replaceVars ./bastion-ssh.sh {
    inherit usernameFile devSubFile prodSubFile bastionSubFile;
    proxychainsConf = "${proxychainsConf}";
  };

  bastionSqlScript = pkgs.replaceVars ./bastion-sql.sh {
    inherit usernameFile devSubFile bastionSubFile oracleHostFile oraclePortFile oracleUserFile oraclePassFile;
    proxychainsConf = "${proxychainsConf}";
  };

  bastionLoginScript = pkgs.replaceVars ./bastion-login.sh {
    proxychainsConf = "${proxychainsConf}";
  };

  binPath = lib.makeBinPath [
    azCli
    pkgs.proxychains-ng
    pkgs.coreutils
    pkgs.wl-clipboard
    pkgs.xclip
    pkgs.openssh
    pkgs.iproute2
    pkgs.gawk
    pkgs.gnugrep
  ];

  bastion-ssh =
    pkgs.runCommand "bastion-ssh" {
      nativeBuildInputs = [pkgs.makeWrapper];
    } ''
      install -Dm755 ${bastionSshScript} $out/bin/bastion-ssh
      patchShebangs $out/bin/bastion-ssh
      wrapProgram $out/bin/bastion-ssh --prefix PATH : ${binPath}
    '';

  bastion-sql =
    pkgs.runCommand "bastion-sql" {
      nativeBuildInputs = [pkgs.makeWrapper];
    } ''
      install -Dm755 ${bastionSqlScript} $out/bin/bastion-sql
      patchShebangs $out/bin/bastion-sql
      wrapProgram $out/bin/bastion-sql --prefix PATH : ${binPath}
    '';

  bastion-login =
    pkgs.runCommand "bastion-login" {
      nativeBuildInputs = [pkgs.makeWrapper];
    } ''
      install -Dm755 ${bastionLoginScript} $out/bin/bastion-login
      patchShebangs $out/bin/bastion-login
      wrapProgram $out/bin/bastion-login --prefix PATH : ${binPath}
    '';
in {
  config = lib.mkIf pkgs.stdenv.isLinux {
    home.packages = [
      azCli
      bastion-ssh
      bastion-sql
      bastion-login
      sqldeveloper
      pkgs.jetbrains.datagrip
      pkgs.sqlcl
      pkgs.proxychains-ng
      pkgs.azure-storage-azcopy
    ];

    # Default ON: every `bastion-ssh` invocation routes through the
    # boeingvpn-ui SOCKS5 listener via proxychains-ng. Override per-call
    # with `BASTION_SSH_VIA_SOCKS= bastion-ssh ...` (empty value) if the
    # tunnel isn't up and you want to try direct.
    home.sessionVariables.BASTION_SSH_VIA_SOCKS = "1";
  };
}
