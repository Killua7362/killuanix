{...}: {
  imports = [
    ./portainer.nix
    ./searxng.nix
    ./litellm.nix
  ];

  # ── quadlet-nix: Rootful container orchestration ──
  virtualisation.quadlet = {
    enable = true;

    # ── Shared volumes ──
    volumes = {
      portainer_data.volumeConfig = {};
    };

    # ── Shared networks ──
    networks = {
      portainer-net.networkConfig = {
        subnets = ["10.89.1.0/24"];
      };
    };
  };
}
