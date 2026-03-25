{
  pkgs,
  config,
  lib,
  ...
}: {
  virtualisation.quadlet.containers.qdrant = {
    autoStart = true;

    containerConfig = {
      image = "docker.io/qdrant/qdrant:v1.14.0";
      publishPorts = [
        "6333:6333" # REST API
        "6334:6334" # gRPC
      ];
      volumes = [
        "${config.xdg.dataHome}/qdrant/storage:/qdrant/storage:z"
        "${config.xdg.dataHome}/qdrant/snapshots:/qdrant/snapshots:z"
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
      Description = "Qdrant Vector Database";
      After = ["network-online.target" "podman.socket"];
      Requires = ["podman.socket"];
    };
  };
}
