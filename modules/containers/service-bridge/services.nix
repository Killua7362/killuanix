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
    {
      # Browser viewer for the cliphist clipboard store (system unit, no
      # autostart — start it from here). See modules/containers/cliphist-viewer/.
      # No CDN icon for cliphist exists, so a self-contained base64 SVG data URI
      # is passed verbatim (service-bridge only rewrites si:/di: prefixes).
      name = "Clipboard";
      unit = "cliphist-viewer.service";
      url = "http://localhost:8899";
      icon = "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjY2RkNmY0IiBzdHJva2Utd2lkdGg9IjIiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIgc3Ryb2tlLWxpbmVqb2luPSJyb3VuZCI+PHJlY3QgeD0iOCIgeT0iMiIgd2lkdGg9IjgiIGhlaWdodD0iNCIgcng9IjEiLz48cGF0aCBkPSJNOCA0SDZhMiAyIDAgMCAwLTIgMnYxNGEyIDIgMCAwIDAgMiAyaDEyYTIgMiAwIDAgMCAyLTJWNmEyIDIgMCAwIDAtMi0yaC0yIi8+PHBhdGggZD0iTTkgMTJoNk05IDE2aDQiLz48L3N2Zz4=";
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
      name = "iCloud Drive";
      unit = "icloud-drive.service";
      url = null;
      icon = "si:icloud";
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
