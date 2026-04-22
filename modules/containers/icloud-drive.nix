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
{
  config,
  lib,
  pkgs,
  ...
}: let
  userCfg = (import ../common/user.nix).userConfig;

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
    excludeShellChecks = ["SC2016"];
    text = ''
      set -euo pipefail

      SERVICE=icloud-drive.service
      CONTAINER=icloud-drive
      SECRET=${sopsPath "icloud_email"}

      wait_ready() {
        # Wait up to 15s for the container to accept exec.
        for _ in $(seq 1 15); do
          if sudo podman exec "$CONTAINER" true 2>/dev/null; then
            return 0
          fi
          sleep 1
        done
        echo "error: container $CONTAINER did not become ready" >&2
        return 1
      }

      ensure_running() {
        if ! systemctl is-active --quiet "$SERVICE"; then
          sudo systemctl start "$SERVICE"
        fi
        wait_ready
      }

      case "''${1:-help}" in
        login)
          echo "Starting container for login..."
          ensure_running
          email=$(sudo cat "$SECRET")
          echo "Logging in as $email — enter Apple ID password, then the 2FA code."
          sudo podman exec -it "$CONTAINER" \
            icloud --username="$email" --session-directory=/config/session_data
          echo
          echo "Login complete. Run 'icloud sync' to start a sync."
          ;;

        sync)
          echo "Starting sync (sync_interval is 1y, so this runs exactly once)."
          echo "Press Ctrl-C once you see the sync finish — the container will be stopped."
          sudo systemctl start "$SERVICE"
          trap 'echo; echo "Stopping container..."; sudo systemctl stop "$SERVICE" >/dev/null 2>&1 || true' EXIT INT TERM
          sudo journalctl -u "$SERVICE" -f --since=now
          ;;

        stop)
          sudo systemctl stop "$SERVICE"
          echo "Stopped."
          ;;

        status)
          systemctl status "$SERVICE" --no-pager --lines=0 || true
          echo
          echo "Sync directory: ${hostSyncDir}"
          ls -la "${hostSyncDir}" 2>/dev/null || true
          ;;

        help | -h | --help)
          cat <<EOF
      icloud — on-demand iCloud Drive + Photos sync

      Usage: icloud <command>

        login    Authenticate with Apple ID (one-time; re-run when 2FA session
                 expires, roughly every 60 days)
        sync     Start one sync pass; tail logs; Ctrl-C to stop when done
        stop     Stop the sync container
        status   Show service status + sync directory contents
        help     Show this help

      Files land in: ${hostSyncDir}
      EOF
          ;;

        *)
          echo "unknown command: $1" >&2
          echo "run 'icloud help' for usage" >&2
          exit 2
          ;;
      esac
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
