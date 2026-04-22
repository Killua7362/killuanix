# Qdrant Vector DB — vector store reachable at http://localhost:6333
# (REST + dashboard) and :6334 (gRPC). Used by code-index MCP as the
# embeddings backend; dashboard is bookmarked on the Firefox homepage.
{...}: {
  systemd.tmpfiles.rules = [
    "d /var/lib/qdrant 0755 root root -"
    "d /var/lib/qdrant/storage 0755 root root -"
    "d /var/lib/qdrant/snapshots 0755 root root -"
  ];

  virtualisation.quadlet.containers.qdrant = {
    autoStart = true;

    containerConfig = {
      image = "docker.io/qdrant/qdrant:v1.14.0";
      publishPorts = [
        "6333:6333" # REST API
        "6334:6334" # gRPC
      ];
      volumes = [
        "/var/lib/qdrant/storage:/qdrant/storage:z"
        "/var/lib/qdrant/snapshots:/qdrant/snapshots:z"
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
