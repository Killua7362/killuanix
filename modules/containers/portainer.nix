{...}: {
  # ── Portainer CE (rootful, using docker socket) ──
  virtualisation.quadlet.containers.portainer = {
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
}
