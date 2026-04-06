{
  pkgs,
  config,
  lib,
  ...
}: {
  imports = [
    ./searxng.nix
  ];

  # ── quadlet-nix: Rootful container orchestration ──
  virtualisation.quadlet = {
    # ── Shared volumes ──
    volumes = {
      portainer_data = {
        volumeConfig = {};
      };
    };

    # ── Shared networks ──
    networks = {
      portainer-net = {
        networkConfig = {
          subnets = ["10.89.1.0/24"];
        };
      };
    };

    # ── Portainer CE (rootful, using docker socket) ──
    containers.portainer = {
      autoStart = true;

      containerConfig = {
        image = "docker.io/portainer/portainer-ce:2.21.5";
        publishPorts = [
          "8000:8000"
          "9443:9443"
        ];
        volumes = [
          "portainer_data:/data"
          "/var/run/docker.sock:/var/run/docker.sock:z"
        ];
        labels = [
          "io.containers.autoupdate=registry"
        ];
      };

      serviceConfig = {
        Restart = "always";
        TimeoutStartSec = 300;
      };

      unitConfig = {
        Description = "Portainer CE - Container Management";
        After = ["network-online.target"];
      };
    };
  };
}
