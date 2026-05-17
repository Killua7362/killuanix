# Element Web — Matrix web client, reachable at http://127.0.0.1:8009.
#
# config.json is rendered every boot by element-web-config.service and
# bind-mounted into the container's nginx docroot. The default-server entry
# points at the local Synapse client-server endpoint.
#
# Mobile (Element X) is independent of this container — point it at
# http://<host>:8008 (or your Tailscale serve URL) directly.
{...}: let
  serverName = "matrix.killua.local";

  configJson = builtins.toJSON {
    default_server_config = {
      "m.homeserver" = {
        base_url = "http://127.0.0.1:8008";
        server_name = serverName;
      };
    };
    brand = "Element";
    disable_guests = true;
    disable_3pid_login = true;
    disable_login_language_selector = false;
    show_labs_settings = false;
    default_country_code = "IN";
    permalink_prefix = "https://matrix.to";
    integrations_ui_url = "";
    integrations_rest_url = "";
    integrations_widgets_urls = [];
  };
in {
  virtualisation.quadlet.containers.element-web = {
    autoStart = false;

    containerConfig = {
      image = "docker.io/vectorim/element-web:latest";
      networks = ["matrix-net"];
      publishPorts = ["127.0.0.1:8009:80"];
      volumes = [
        "/run/element-web/config.json:/app/config.json:ro"
      ];
      # nginx in this image runs as non-root and binds port 80. Without
      # NET_BIND_SERVICE in the bounding set, bind() fails with EACCES.
      # Lowering ip_unprivileged_port_start in the container's net ns lets
      # any uid bind port 80, no extra capability needed.
      sysctl = {
        "net.ipv4.ip_unprivileged_port_start" = "80";
      };
      labels = ["io.containers.autoupdate=registry"];
    };

    serviceConfig = {
      Restart = "always";
      TimeoutStartSec = 120;
    };

    unitConfig = {
      Description = "Element Web — Matrix client";
      After = ["network-online.target" "podman.socket" "element-web-config.service"];
      Requires = ["podman.socket" "element-web-config.service"];
    };
  };

  systemd.services.element-web-config = {
    description = "Render Element Web config.json";
    wantedBy = ["multi-user.target"];
    before = ["element-web.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      RuntimeDirectory = "element-web";
      RuntimeDirectoryMode = "0755";
    };
    script = ''
      cat > /run/element-web/config.json <<'EOF'
      ${configJson}
      EOF
      chmod 0644 /run/element-web/config.json
    '';
  };
}
