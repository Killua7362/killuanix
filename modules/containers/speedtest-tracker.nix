# Speedtest Tracker — alexjustesen/speedtest-tracker (linuxserver image).
# Self-hosted Ookla speedtest runner with a web UI + REST API. Glance hits
# `/api/v1/results/latest` + `/api/v1/stats` to render the right-column Speed
# card on the Home page (see modules/containers/glance.nix).
#
# Reachable at http://localhost:8765. Container runs on its own user-defined
# port-published mode (NOT host network) because the linuxserver image hardcodes
# its internal nginx to :80 and overriding that via env is fiddly — port-publish
# keeps it simple. Glance reaches it over the host loopback because the glance
# container DOES use `networks = ["host"]` (see glance.nix top-of-file comment).
#
# Two sops-driven values:
#   - speedtest_tracker_app_key       — APP_KEY env var, Laravel encryption key.
#                                       Generate with: openssl rand -base64 32
#                                       MUST be set before first boot, and MUST
#                                       NOT change afterwards or stored data
#                                       (history, settings) becomes unreadable.
#   - speedtest_tracker_api_token     — API token generated INSIDE the UI after
#                                       first boot (Settings → API tokens →
#                                       Create token). Used by Glance only;
#                                       rotate by deleting + recreating in UI.
#
# First-boot bootstrap (manual, one-shot):
#   1. Populate `speedtest_tracker_app_key` in sops (otherwise the container
#      crash-loops with "No application encryption key has been specified").
#   2. `sudo systemctl start speedtest-tracker`
#   3. Open http://localhost:8765, log in with default creds
#      `admin@example.com` / `password` — change the password immediately.
#   4. Settings → API tokens → "Create token" → copy → paste into sops as
#      `speedtest_tracker_api_token`, re-encrypt.
#   5. `sudo systemctl restart glance-env glance` so Glance picks up the token.
#   6. Trigger an immediate test (optional):
#        sudo podman exec speedtest-tracker php /app/www/artisan speedtest:run
#
# Schedule: SPEEDTEST_SCHEDULE cron string runs internally every 6h by default.
# Retention: PRUNE_RESULTS_OLDER_THAN drops history beyond 30 days.
{
  pkgs,
  config,
  ...
}: let
  sopsPath = name: config.sops.secrets.${name}.path;
in {
  virtualisation.quadlet.containers.speedtest-tracker = {
    autoStart = true;

    containerConfig = {
      image = "lscr.io/linuxserver/speedtest-tracker:latest";
      publishPorts = ["127.0.0.1:8765:80"];
      volumes = [
        "speedtest_data:/config:z"
      ];
      environments = {
        PUID = "1000";
        PGID = "1000";
        TZ = "Asia/Kolkata";
        DB_CONNECTION = "sqlite";
        SPEEDTEST_SCHEDULE = "0 */6 * * *";
        PRUNE_RESULTS_OLDER_THAN = "30";
        APP_URL = "http://localhost:8765";
        APP_TIMEZONE = "Asia/Kolkata";
      };
      environmentFiles = ["/run/speedtest-tracker/env"];
      labels = ["io.containers.autoupdate=registry"];
    };

    serviceConfig = {
      Restart = "always";
      TimeoutStartSec = 300;
    };

    unitConfig = {
      Description = "Speedtest Tracker - scheduled Ookla speedtests + API";
      After = [
        "network-online.target"
        "podman.socket"
        "speedtest-tracker-env.service"
      ];
      Requires = [
        "podman.socket"
        "speedtest-tracker-env.service"
      ];
    };
  };

  systemd.services.speedtest-tracker-env = {
    description = "Assemble Speedtest Tracker env file from sops secrets";
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      RuntimeDirectory = "speedtest-tracker";
      RuntimeDirectoryMode = "0700";
    };
    script = ''
      read_secret() {
        local path="$1"
        [ -f "$path" ] && cat "$path" || echo ""
      }

      umask 077
      {
        printf 'APP_KEY=%s\n' "$(read_secret ${sopsPath "speedtest_tracker_app_key"})"
      } > /run/speedtest-tracker/env
    '';
  };
}
