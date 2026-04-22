# Mermaid Live Editor — self-hosted Mermaid diagram playground, reachable at
# http://localhost:8898. Pairs with the `mermaid` MCP server so Claude Code can
# render .mmd files directly while users preview/tweak them in-browser.
{...}: {
  virtualisation.quadlet.containers.mermaid-live = {
    autoStart = true;

    containerConfig = {
      image = "ghcr.io/mermaid-js/mermaid-live-editor:latest";
      publishPorts = [
        "8898:8080"
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
      Description = "Mermaid Live Editor - Mermaid diagram playground";
      After = ["network-online.target" "podman.socket"];
      Requires = ["podman.socket"];
    };
  };
}
