# Homepage — gethomepage/homepage dashboard for all self-hosted services.
# Reachable at http://localhost:8880. Wired into Firefox's startup homepage in
# modules/common/programs/browsers/firefox/default.nix.
#
# Config is generated from Nix (writeText) and mounted read-only into
# /app/config/. To add a new service card, extend the `services` list below —
# the group key creates a card column on the dashboard.
{pkgs, ...}: let
  settingsYaml = pkgs.writeText "homepage-settings.yaml" (builtins.toJSON {
    title = "killuanix";
    headerStyle = "clean";
    theme = "dark";
    color = "slate";
    layout = {
      Diagrams = {
        style = "row";
        columns = 2;
      };
      Infra = {
        style = "row";
        columns = 3;
      };
      AI = {
        style = "row";
        columns = 3;
      };
    };
    background = {
      blur = "sm";
      saturate = 50;
      brightness = 50;
      opacity = 50;
    };
    hideVersion = true;
    disableCollapse = true;
    showStats = false;
  });

  # Service cards. Group → list of {name, href, icon, description, …}.
  servicesYaml = pkgs.writeText "homepage-services.yaml" (builtins.toJSON [
    {
      Diagrams = [
        {
          Excalidraw = {
            icon = "excalidraw.png";
            href = "http://localhost:8899";
            description = "Virtual whiteboard for hand-drawn diagrams";
          };
        }
        {
          "Mermaid Live" = {
            icon = "mermaid.png";
            href = "http://localhost:8898";
            description = "Live editor for Mermaid diagrams";
          };
        }
      ];
    }
    {
      Infra = [
        {
          Portainer = {
            icon = "portainer.png";
            href = "https://localhost:9443";
            description = "Container management UI";
          };
        }
        {
          SearXNG = {
            icon = "searxng.png";
            href = "http://localhost:8888";
            description = "Privacy-respecting metasearch";
          };
        }
        {
          Qdrant = {
            icon = "qdrant.png";
            href = "http://localhost:6333/dashboard";
            description = "Vector database + dashboard";
          };
        }
      ];
    }
    {
      AI = [
        {
          LiteLLM = {
            icon = "mdi-api";
            href = "http://localhost:4000";
            description = "LLM proxy + MCP runtime";
          };
        }
        {
          "MCP Hub" = {
            icon = "mdi-server-network";
            href = "http://localhost:31415";
            description = "MCP server registry (enable via mcphub.nix)";
          };
        }
      ];
    }
  ]);

  # Quick-access links (rendered as a separate section below services).
  bookmarksYaml = pkgs.writeText "homepage-bookmarks.yaml" (builtins.toJSON [
    {
      Developer = [
        {
          GitHub = [
            {
              abbr = "GH";
              href = "https://github.com/Killua7362";
            }
          ];
        }
        {
          "NixOS Search" = [
            {
              abbr = "NP";
              href = "https://search.nixos.org/packages";
            }
          ];
        }
        {
          "Home Manager Options" = [
            {
              abbr = "HM";
              href = "https://home-manager-options.extranix.com/";
            }
          ];
        }
        {
          Flake = [
            {
              abbr = "FK";
              href = "https://github.com/Killua7362/killuanix";
            }
          ];
        }
      ];
    }
    {
      Docs = [
        {
          "Arkenfox Wiki" = [
            {
              abbr = "AF";
              href = "https://github.com/arkenfox/user.js/wiki";
            }
          ];
        }
        {
          "Hyprland Wiki" = [
            {
              abbr = "HY";
              href = "https://wiki.hyprland.org/";
            }
          ];
        }
        {
          "Claude Docs" = [
            {
              abbr = "CL";
              href = "https://docs.claude.com/";
            }
          ];
        }
      ];
    }
  ]);

  # Widget row shown at the top of the dashboard.
  widgetsYaml = pkgs.writeText "homepage-widgets.yaml" (builtins.toJSON [
    {
      greeting = {
        text_size = "xl";
        text = "killuanix";
      };
    }
    {
      datetime = {
        text_size = "l";
        format = {
          dateStyle = "long";
          timeStyle = "short";
          hour12 = false;
        };
      };
    }
    {
      search = {
        provider = "custom";
        url = "http://localhost:8888/search?q=";
        target = "_blank";
      };
    }
  ]);

  # Empty docker.yaml keeps homepage happy even if we don't wire in
  # Docker/Podman socket integration yet.
  dockerYaml = pkgs.writeText "homepage-docker.yaml" "";
in {
  virtualisation.quadlet.containers.homepage = {
    autoStart = true;

    containerConfig = {
      image = "ghcr.io/gethomepage/homepage:latest";
      publishPorts = [
        "8880:3000"
      ];
      volumes = [
        "${settingsYaml}:/app/config/settings.yaml:ro,z"
        "${servicesYaml}:/app/config/services.yaml:ro,z"
        "${bookmarksYaml}:/app/config/bookmarks.yaml:ro,z"
        "${widgetsYaml}:/app/config/widgets.yaml:ro,z"
        "${dockerYaml}:/app/config/docker.yaml:ro,z"
      ];
      environments = {
        # v0.9+ enforces an allowed-hosts allowlist. Cover the three ways the
        # dashboard gets reached in practice.
        HOMEPAGE_ALLOWED_HOSTS = "localhost:8880,127.0.0.1:8880,host.containers.internal:8880";
      };
      labels = [
        "io.containers.autoupdate=registry"
      ];
    };

    serviceConfig = {
      Restart = "always";
      TimeoutStartSec = 300;
    };

    unitConfig = {
      Description = "Homepage - Self-hosted service dashboard";
      After = ["network-online.target" "podman.socket"];
      Requires = ["podman.socket"];
    };
  };
}
