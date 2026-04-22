# Excalidraw — self-hosted virtual whiteboard, reachable at http://localhost:8899.
# Pairs with the `excalidraw` MCP server in modules/common/mcp-servers.nix so
# Claude Code can write .excalidraw JSON files that this instance opens.
{...}: {
  virtualisation.quadlet.containers.excalidraw = {
    autoStart = true;

    containerConfig = {
      image = "docker.io/excalidraw/excalidraw:latest";
      publishPorts = [
        "8899:80"
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
      Description = "Excalidraw - Virtual whiteboard for hand-drawn diagrams";
      After = ["network-online.target" "podman.socket"];
      Requires = ["podman.socket"];
    };
  };
}
