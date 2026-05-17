# RSS-Bridge — generate RSS/Atom feeds for sites that removed or never had
# them. Web UI at http://localhost:8085. Single quadlet container, no auth
# (loopback-only), cache persisted in `rss_bridge_cache`.
#
# Usage:
#   1. Visit http://localhost:8085, pick a bridge (e.g. CssSelectorBridge,
#      FilterBridge, GoogleSearchBridge), fill fields, copy the generated
#      Atom URL.
#   2. From inside another container (FreshRSS), swap host `localhost` for
#      `host.containers.internal` — i.e. paste
#      `http://host.containers.internal:8085/?action=display&bridge=...&format=Atom`
#      into FreshRSS's "Add feed" form.
#
# Whitelist `*` enables every shipped bridge; the image otherwise locks them
# all off. No sops secrets needed.
{pkgs, ...}: let
  whitelist = pkgs.writeText "rss-bridge-whitelist.txt" "*\n";
in {
  virtualisation.quadlet.containers.rss-bridge = {
    autoStart = true;

    containerConfig = {
      image = "docker.io/rssbridge/rss-bridge:latest";
      # Bind to all interfaces so freshrss (different podman network) can
      # reach via `host.containers.internal`. Host firewall blocks external.
      publishPorts = ["8085:80"];
      volumes = [
        "${whitelist}:/app/whitelist.txt:ro,z"
        "rss_bridge_cache:/app/cache:z"
      ];
      labels = ["io.containers.autoupdate=registry"];
    };

    serviceConfig = {
      Restart = "always";
      TimeoutStartSec = 120;
    };

    unitConfig = {
      Description = "RSS-Bridge - generate feeds for sites that lack them";
      After = ["network-online.target"];
    };
  };
}
