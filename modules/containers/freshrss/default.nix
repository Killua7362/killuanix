# FreshRSS — self-hosted RSS aggregator with Google Reader + Fever APIs,
# reachable at http://localhost:8083. Single quadlet container backed by SQLite
# (bundled in the image — no separate DB service needed for a personal
# instance).
#
# First-boot install: the upstream image's entrypoint auto-creates the admin
# user when ADMIN_USERNAME + ADMIN_EMAIL + ADMIN_PASSWORD + ADMIN_API_PASSWORD
# are present. Once /var/www/FreshRSS/data is populated the entrypoint skips
# the installer; rotating the sops passwords here will NOT change the running
# credentials (wipe freshrss_data volume to re-seed, or change in the FreshRSS
# UI under Configuration → Authentication). To re-apply just the API password
# without wiping, freshrss-bootstrap-api-pw.service does that on every rebuild.
#
# Declarative layering (see sibling files):
#   • ./extensions.nix — read-only bind-mount of selected pkgs.freshrss-extensions
#   • ./bootstrap.nix  — per-user config.php materialization + API-password re-apply
#   • ./opml.nix       — optional sops-encrypted OPML import with a daily timer
#
# RSSGuard pairing: Add account → "FreshRSS" plugin → URL
#   http://localhost:8083/api/greader.php
# username = killua, password = ADMIN_API_PASSWORD (NOT the web-login one —
# the Google Reader API takes its own credential).
{
  pkgs,
  config,
  lib,
  ...
}: let
  sopsPath = name: config.sops.secrets.${name}.path;
in {
  imports = [
    ./extensions.nix
    ./bootstrap.nix
    ./opml.nix
  ];

  virtualisation.quadlet.containers.freshrss = {
    autoStart = true;

    containerConfig = {
      image = "docker.io/freshrss/freshrss:latest";
      publishPorts = ["127.0.0.1:8083:80"];
      volumes = [
        "freshrss_data:/var/www/FreshRSS/data:z"
        "freshrss_extensions:/var/www/FreshRSS/extensions:z"
        # Read-only bind-mount of the nix-built bundle of enabled extensions.
        # Mounted at a sub-path so it doesn't shadow the image's built-in
        # lib/core-extensions/ (CustomCSS, CustomJS, Tor, etc.); FreshRSS picks
        # it up via THIRDPARTY_EXTENSIONS_PATH.
        "${config.services.freshrssExtensions.bundle}:/var/www/FreshRSS/extensions/nix:ro,z"
      ];
      environments = {
        TZ = "Asia/Kolkata";
        CRON_MIN = "*/15";
        ADMIN_EMAIL = "akshay@altdigital.tech";
        ADMIN_USERNAME = "killua";
        PUBLISHED_PORT = "8083";
        # Pin behavior across upstream entrypoint changes.
        FRESHRSS_ENV = "production";
        LISTEN = "0.0.0.0:80";
        TRUSTED_PROXY = "0";
        # Tell FreshRSS to also scan the nix-managed extension bundle.
        THIRDPARTY_EXTENSIONS_PATH = "/var/www/FreshRSS/extensions/nix";
      };
      environmentFiles = ["/run/freshrss/env"];
      labels = ["io.containers.autoupdate=registry"];
    };

    serviceConfig = {
      Restart = "always";
      TimeoutStartSec = 300;
    };

    unitConfig = {
      Description = "FreshRSS - Self-hosted RSS aggregator";
      After = [
        "network-online.target"
        "podman.socket"
        "freshrss-env.service"
      ];
      Requires = [
        "podman.socket"
        "freshrss-env.service"
      ];
    };
  };

  # Stage sops-decrypted admin + API passwords into an env file the container
  # reads at start. Mirrors searxng-env.service.
  systemd.services.freshrss-env = {
    description = "Assemble FreshRSS env file from sops secrets";
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      RuntimeDirectory = "freshrss";
      RuntimeDirectoryMode = "0700";
    };
    script = ''
      umask 077
      {
        printf 'ADMIN_PASSWORD=%s\n' "$(cat ${sopsPath "freshrss_admin_password"})"
        printf 'ADMIN_API_PASSWORD=%s\n' "$(cat ${sopsPath "freshrss_admin_api_password"})"
      } > /run/freshrss/env
    '';
  };

  # Shared sentinel dir used by bootstrap + import oneshots.
  systemd.tmpfiles.rules = [
    "d /var/lib/freshrss 0700 root root -"
    "d /var/lib/freshrss/state 0700 root root -"
  ];
}
