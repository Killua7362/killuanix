{ pkgs, config, lib, ... }:
{
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
        # Mount the rootless podman socket so Portainer can manage containers
        "/run/user/1000/podman/podman.sock:/var/run/docker.sock:z"
      ];
      labels = [
        "io.containers.autoupdate=registry"
      ];
      securityLabelDisable = true; # needed for socket access
    };

    serviceConfig = {
      Restart = "always";
      TimeoutStartSec = 300;
    };

    unitConfig = {
      Description = "Portainer CE - Container Management";
      After = [ "network-online.target" "podman.socket" ];
      Requires = [ "podman.socket" ];
    };

  };

}
