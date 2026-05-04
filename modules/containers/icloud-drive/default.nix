# iCloud Drive + Photos sync (mandarons/icloud-drive-docker), on-demand only.
#
# Pulls iCloud Drive + Photos down to ~/iCloud so Nemo can browse them locally.
# DOWNLOAD-ONLY — edits made on Linux are not pushed back to iCloud.
#
# The container does NOT start automatically and does NOT auto-restart. All
# activity is driven by the `icloud` CLI installed system-wide:
#
#   icloud login    — one-time Apple ID auth (also re-run when Apple expires
#                     the session cookie, roughly every ~60 days)
#   icloud sync     — start container, tail logs, Ctrl-C when done to stop
#   icloud stop     — stop the container
#   icloud status   — show container status + sync dir
#
# The Apple ID email is pulled from sops (`icloud_email`) so it isn't checked
# into the flake. A oneshot systemd service renders the config at runtime.
#
# CLI body lives in ./scripts/icloud.sh; the writeShellApplication wrapper
# below sets ICLOUD_EMAIL_FILE and ICLOUD_SYNC_DIR env vars before exec'ing it.
{
  config,
  lib,
  pkgs,
  ...
}: let
  userCfg = (import ../../common/user.nix).userConfig;

  # Host path that Nemo browses — lives directly in $HOME.
  hostSyncDir = "${userCfg.homeDirectories.linux}/iCloud";

  configTemplate = pkgs.writeText "icloud-config.yaml.tmpl" (builtins.toJSON {
    app = {
      credentials.username = "@ICLOUD_EMAIL@";
      region = "global";
      logger = {
        level = "info";
        filename = "/config/icloud.log";
      };
    };
    drive = {
      destination = "/app/icloud/drive";
      remove_obsolete = false;
      # Large sync_interval so one `icloud sync` invocation does a single pass
      # and then the container idles until the user stops it.
      sync_interval = 31536000; # 1 year
    };
    photos = {
      destination = "/app/icloud/photos";
      remove_obsolete = false;
      sync_interval = 31536000;
      all_albums = false;
      folder_format = "%Y/%m";
    };
  });

  sopsPath = name: config.sops.secrets.${name}.path;

  icloudCli = pkgs.writeShellApplication {
    name = "icloud";
    runtimeInputs = with pkgs; [systemd podman coreutils];
    text = ''
      export ICLOUD_EMAIL_FILE=${sopsPath "icloud_email"}
      export ICLOUD_SYNC_DIR=${hostSyncDir}
      exec bash ${./scripts/icloud.sh} "$@"
    '';
  };
in {
  # System-wide CLI.
  environment.systemPackages = [icloudCli];

  # Ensure the host sync directory exists and is owned by the user before
  # the container mounts it (container writes as UID 1000 via PUID/PGID).
  systemd.tmpfiles.rules = [
    "d ${hostSyncDir}         0755 ${userCfg.username} users - -"
    "d ${hostSyncDir}/drive   0755 ${userCfg.username} users - -"
    "d ${hostSyncDir}/photos  0755 ${userCfg.username} users - -"
  ];

  # Render /run/icloud-drive/config.yaml from template + sops-decrypted email.
  systemd.services.icloud-drive-config = {
    description = "Render iCloud Drive config.yaml from sops secrets";
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      RuntimeDirectory = "icloud-drive";
      # 0755 so the container (UID 1000) can read the rendered config.
      RuntimeDirectoryMode = "0755";
    };
    script = ''
      email="$(cat ${sopsPath "icloud_email"})"
      ${pkgs.gnused}/bin/sed "s|@ICLOUD_EMAIL@|$email|g" \
        ${configTemplate} > /run/icloud-drive/config.yaml
      chmod 0644 /run/icloud-drive/config.yaml
    '';
  };

  virtualisation.quadlet = {
    volumes = {
      icloud-session.volumeConfig = {};
      # Python keyring (stores the Apple ID password after first-run auth).
      icloud-keyring.volumeConfig = {};
    };

    containers.icloud-drive = {
      # No auto-start on boot; no auto-restart. Purely driven by `icloud` CLI.
      autoStart = false;

      containerConfig = {
        image = "docker.io/mandarons/icloud-drive:latest";

        volumes = [
          "/run/icloud-drive/config.yaml:/config/config.yaml:ro,z"
          "icloud-session:/config/session_data"
          "icloud-keyring:/home/abc/.local/share/python_keyring"
          "${hostSyncDir}:/app/icloud:z"
        ];

        environments = {
          ENV_CONFIG_FILE_PATH = "/config/config.yaml";
          TZ = "Asia/Kolkata";
          PUID = "1000";
          PGID = "100";
        };

        labels = [
          "io.containers.autoupdate=registry"
        ];
      };

      serviceConfig = {
        Restart = "no";
        TimeoutStartSec = 300;
      };

      unitConfig = {
        Description = "iCloud Drive + Photos sync (on-demand via `icloud` CLI)";
        After = [
          "network-online.target"
          "icloud-drive-config.service"
        ];
        Wants = ["network-online.target"];
        Requires = ["icloud-drive-config.service"];
      };
    };
  };
}
