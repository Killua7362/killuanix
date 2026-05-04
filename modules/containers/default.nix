{...}: {
  imports = [
    ./portainer.nix
    ./searxng.nix
    ./litellm.nix
    ./icloud-drive
    ./excalidraw.nix
    ./mermaid-live.nix
    ./homepage.nix
    ./qdrant.nix
    ./linkding.nix
    ./cronicle
  ];

  # ── quadlet-nix: Rootful container orchestration ──
  virtualisation.quadlet = {
    enable = true;

    # ── Shared volumes ──
    volumes = {
      portainer_data.volumeConfig = {};
      linkding_data.volumeConfig = {};
      cronicle_data.volumeConfig = {};
      cronicle_logs.volumeConfig = {};
      cronicle_plugins.volumeConfig = {};
    };

    # ── Shared networks ──
    networks = {
      portainer-net.networkConfig = {
        subnets = ["10.89.1.0/24"];
      };
    };
  };
}
