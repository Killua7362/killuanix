# service-bridge service catalogue.
#
# Source of truth for both glance widgets (status tiles + control buttons) and
# the FastAPI bridge daemon. Each entry must name exactly one systemd unit. A
# null `url` means the service has no HTTP probe — status is derived from
# `systemctl is-active` alone, and "error" is impossible (only up/down).
#
# `homepage = true` puts the entry on glance's Home-page tile widget (no
# buttons). Every entry — homepage or not — appears on the Containers page
# with start/stop/restart buttons.
{
  services = [
    # ── Home page hero services ────────────────────────────────────
    {
      name = "Karakeep";
      unit = "karakeep.service";
      url = "http://localhost:9090";
      icon = "di:karakeep";
      homepage = true;
    }
    {
      name = "FreshRSS";
      unit = "freshrss.service";
      url = "http://localhost:8083";
      icon = "si:rss";
      homepage = true;
    }
    {
      name = "SearXNG";
      unit = "searxng.service";
      url = "http://localhost:8888";
      icon = "si:searxng";
      homepage = true;
    }
    {
      name = "Speedtest";
      unit = "speedtest-tracker.service";
      url = "http://localhost:8765";
      icon = "si:speedtest";
      homepage = true;
    }
    # ── Containers-tab only ────────────────────────────────────────
    {
      name = "Glance";
      unit = "glance.service";
      url = "http://localhost:8880";
      icon = "si:glance";
    }
    {
      name = "Portainer";
      unit = "portainer.service";
      url = "https://localhost:9443";
      icon = "si:portainer";
      allowInsecure = true;
    }
    {
      name = "Cronicle";
      unit = "cronicle.service";
      url = "http://localhost:3012";
      icon = "si:clockify";
    }
    {
      name = "Element";
      unit = "element-web.service";
      url = "http://localhost:8009";
      icon = "si:element";
    }
    {
      name = "Qdrant";
      unit = "qdrant.service";
      url = "http://localhost:6333";
      icon = "si:qdrant";
    }
    {
      name = "LiteLLM";
      unit = "litellm.service";
      url = "http://localhost:4000/health/liveliness";
      icon = "si:openai";
    }
    {
      name = "Excalidraw";
      unit = "excalidraw.service";
      url = "http://localhost:8899";
      icon = "si:excalidraw";
    }
    {
      name = "Mermaid Live";
      unit = "mermaid-live.service";
      url = "http://localhost:8898";
      icon = "si:mermaid";
    }
    {
      name = "RSS Bridge";
      unit = "rss-bridge.service";
      url = "http://localhost:8085";
      icon = "si:rss";
    }
    {
      name = "Karakeep Meili";
      unit = "karakeep-meili.service";
      url = null;
      icon = "si:meilisearch";
    }
    {
      name = "Synapse";
      unit = "synapse.service";
      url = "http://localhost:8008/health";
      icon = "si:matrix";
    }
    {
      name = "Matrix Postgres";
      unit = "matrix-postgres.service";
      url = null;
      icon = "si:postgresql";
    }
    {
      name = "mautrix-telegram";
      unit = "mautrix-telegram.service";
      url = null;
      icon = "si:telegram";
    }
    {
      name = "mautrix-whatsapp";
      unit = "mautrix-whatsapp.service";
      url = null;
      icon = "si:whatsapp";
    }
    {
      name = "mautrix-instagram";
      unit = "mautrix-meta-instagram.service";
      url = null;
      icon = "si:instagram";
    }
    {
      name = "mautrix-messenger";
      unit = "mautrix-meta-messenger.service";
      url = null;
      icon = "si:messenger";
    }
    {
      name = "iCloud Drive";
      unit = "icloud-drive.service";
      url = null;
      icon = "si:icloud";
    }
    {
      name = "Boeing Mongo";
      unit = "boeing-mongo.service";
      url = null;
      icon = "si:mongodb";
    }
    {
      name = "Boeing Mongo Express";
      unit = "boeing-mongo-express.service";
      url = "http://localhost:8181";
      icon = "si:mongodb";
    }
    {
      name = "Boeing Redis";
      unit = "boeing-redis.service";
      url = null;
      icon = "si:redis";
    }
    {
      name = "Boeing Redis Commander";
      unit = "boeing-redis-commander.service";
      url = "http://localhost:8281";
      icon = "si:redis";
    }
    {
      name = "Boeing Postgres";
      unit = "boeing-postgres.service";
      url = null;
      icon = "si:postgresql";
    }
    {
      name = "Cockpit";
      unit = "cockpit.service";
      url = "http://localhost:9091";
      icon = "si:redhat";
      homepage = true;
    }
  ];
}
