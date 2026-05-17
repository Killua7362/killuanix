# service-bridge — tiny FastAPI daemon that gives Glance widgets a tri-state
# view (up/down/error) of the quadlet container fleet, start/stop/restart
# control buttons, and a Home-page feeds iframe backed by the FreshRSS
# Greader API (categories → tabs). See ./services.nix for the unit allowlist
# and ./bridge.py for the HTTP surface.
#
# Runs as root because the controlled units are root-owned system .service
# units; loopback-only bind on 127.0.0.1:8770 is the security boundary. CORS
# is allow-listed to the glance origin so its custom-api widget can POST from
# the browser tab.
#
# FreshRSS API password is sourced from sops (`freshrss_admin_api_password`)
# via the service-bridge-env oneshot — same pattern as glance-env. Empty
# password tolerated: feeds endpoints return [] and the widget shows "Error".
{
  pkgs,
  config,
  ...
}: let
  sopsPath = name: config.sops.secrets.${name}.path;
  catalogue = import ./services.nix;

  servicesJson = pkgs.writeText "service-bridge-services.json" (builtins.toJSON catalogue);

  pythonEnv = pkgs.python3.withPackages (ps:
    with ps; [
      fastapi
      uvicorn
      httpx
    ]);

  # Stage bridge.py into a directory by itself so uvicorn's --app-dir lookup
  # works. Referencing ./bridge.py directly gives a single-file /nix/store
  # path whose dirname is /nix/store — not importable as a module.
  bridgeDir = pkgs.runCommand "service-bridge-src" {} ''
    mkdir -p $out
    cp ${./bridge.py} $out/bridge.py
  '';
in {
  environment.etc."service-bridge/services.json".source = servicesJson;

  # Build /run/service-bridge/env from sops-decrypted secrets before the
  # bridge starts. Mirrors the glance-env pattern.
  systemd.services.service-bridge-env = {
    description = "Assemble service-bridge env file from sops secrets";
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      RuntimeDirectory = "service-bridge";
      RuntimeDirectoryMode = "0700";
    };
    script = ''
      read_secret() {
        local path="$1"
        [ -f "$path" ] && cat "$path" || echo ""
      }
      umask 077
      {
        printf 'FRESHRSS_BASE=%s\n' 'http://localhost:8083'
        printf 'FRESHRSS_USER=%s\n' 'killua'
        printf 'FRESHRSS_API_PASSWORD=%s\n' "$(read_secret ${sopsPath "freshrss_admin_api_password"})"
      } > /run/service-bridge/env
    '';
  };

  systemd.services.service-bridge = {
    description = "service-bridge — tri-state status + systemctl control for quadlet containers";
    wantedBy = ["multi-user.target"];
    after = [
      "network.target"
      "service-bridge-env.service"
    ];
    requires = ["service-bridge-env.service"];

    environment = {
      SERVICE_BRIDGE_CONFIG = "/etc/service-bridge/services.json";
      SERVICE_BRIDGE_CORS_ORIGIN = "http://localhost:8880";
    };

    serviceConfig = {
      Type = "simple";
      EnvironmentFile = "/run/service-bridge/env";
      ExecStart = "${pythonEnv}/bin/uvicorn --host 127.0.0.1 --port 8770 --app-dir ${bridgeDir} bridge:app";
      Restart = "on-failure";
      RestartSec = 3;

      # Run as root: needs systemctl to control root-owned system units.
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = false;
      ReadWritePaths = [];
    };
  };
}
