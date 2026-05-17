{...}: {
  imports = [
    ./portainer.nix
    ./searxng.nix
    ./litellm.nix
    ./icloud-drive
    ./excalidraw.nix
    ./mermaid-live.nix
    ./glance.nix
    ./qdrant.nix
    ./karakeep.nix
    ./speedtest-tracker.nix
    ./rss-bridge.nix
    ./freshrss
    ./cronicle
    ./boeing
    ./matrix
    ./service-bridge
    ./cockpit.nix
  ];

  # ── quadlet-nix: Rootful container orchestration ──
  virtualisation.quadlet = {
    enable = true;

    # ── Shared volumes ──
    volumes = {
      portainer_data.volumeConfig = {};
      karakeep_data.volumeConfig = {};
      karakeep_meili_data.volumeConfig = {};
      freshrss_data.volumeConfig = {};
      freshrss_extensions.volumeConfig = {};
      rss_bridge_cache.volumeConfig = {};
      speedtest_data.volumeConfig = {};
      cronicle_data.volumeConfig = {};
      cronicle_logs.volumeConfig = {};
      cronicle_plugins.volumeConfig = {};
      boeing_mongo_data.volumeConfig = {};
      boeing_redis_data.volumeConfig = {};
      boeing_pg_data.volumeConfig = {};
      matrix_postgres_data.volumeConfig = {};
      matrix_synapse_data.volumeConfig = {};
      mautrix_telegram_data.volumeConfig = {};
      mautrix_whatsapp_data.volumeConfig = {};
      mautrix_meta_instagram_data.volumeConfig = {};
      mautrix_meta_messenger_data.volumeConfig = {};
    };

    # ── Shared networks ──
    networks = {
      portainer-net.networkConfig = {
        subnets = ["10.89.1.0/24"];
      };
      matrix-net.networkConfig = {
        subnets = ["10.89.2.0/24"];
      };
      karakeep-net.networkConfig = {
        subnets = ["10.89.3.0/24"];
      };
    };
  };
}
