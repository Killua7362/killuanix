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
        columns = 4;
      };
      AI = {
        style = "row";
        columns = 3;
      };
    };
    # Minimal look: no wallpaper, just a flat near-black surface.
    # custom.css below handles the cards.
    hideVersion = true;
    disableCollapse = true;
    showStats = false;
  });

  # Nighttab-inspired look: flat dark-navy surface, left-aligned content,
  # bold large group headers, rectangular tiles with a solid blue bottom-
  # border accent (Nighttab's signature). Big icon stacked over the name,
  # no descriptions. Loaded by homepage from /app/config/custom.css.
  customCss = pkgs.writeText "homepage-custom.css" ''
    :root {
      --bg: #1b2330;
      --surface: #2a3441;
      --surface-hover: #34404f;
      --outline: rgba(255, 255, 255, 0.04);
      --fg: #e6e6e6;
      --fg-dim: #9aa3b1;
      --fg-faint: #6b7280;
      --accent: #2f6fed;
      --accent-bright: #4a8bff;
    }
    html, body, #__next {
      background: var(--bg) !important;
      min-height: 100vh;
      color: var(--fg);
      font-family: ui-sans-serif, system-ui, -apple-system, "Inter", sans-serif;
    }
    /* Left-aligned column, generous left padding like Nighttab. */
    main, [class*="MainLayout"], [class*="layout"] {
      max-width: 1400px !important;
      margin: 0 !important;
      padding: 3rem 2rem 6rem 4rem !important;
    }
    /* Header row (datetime + search) inline, left-aligned. */
    .information-widget, [class*="information-widget"] {
      background: transparent !important;
      display: flex !important;
      align-items: center !important;
      gap: 1.5rem !important;
      margin-bottom: 3rem !important;
    }
    .information-widget-datetime, [class*="datetime"] {
      font-size: 1.4rem !important;
      font-weight: 600 !important;
      color: var(--fg) !important;
      font-variant-numeric: tabular-nums;
      letter-spacing: 0.02em;
    }
    .greeting, [class*="greeting"] { display: none !important; }
    /* Search: borderless rounded rectangle, Nighttab style. */
    [class*="search"] input, input[type="search"] {
      background: transparent !important;
      border: 1px solid var(--surface) !important;
      border-radius: 8px !important;
      padding: 0.7rem 1.2rem !important;
      color: var(--fg) !important;
      width: 540px !important;
      font-size: 0.95rem !important;
    }
    [class*="search"] input::placeholder { color: var(--fg-faint) !important; }
    /* Group headings: bold, white, large, left-aligned. */
    .services-group h2, .bookmarks-group h2, h1, h2 {
      font-weight: 700 !important;
      font-size: 1.4rem !important;
      letter-spacing: -0.01em;
      text-transform: none;
      color: var(--fg) !important;
      margin-top: 2.5rem !important;
      margin-bottom: 1rem !important;
    }
    /* Tiles: rectangular, flat, with a solid blue bottom-border accent. */
    .service-card, .bookmark-card {
      background: var(--surface) !important;
      border: none !important;
      border-bottom: 3px solid var(--accent) !important;
      border-radius: 6px !important;
      box-shadow: none !important;
      padding: 1.5rem 1rem !important;
      min-height: 7.5rem !important;
      display: flex !important;
      flex-direction: column !important;
      align-items: center !important;
      justify-content: center !important;
      gap: 0.6rem !important;
      transition: background 140ms ease, border-color 140ms ease;
    }
    .service-card:hover, .bookmark-card:hover {
      background: var(--surface-hover) !important;
      border-bottom-color: var(--accent-bright) !important;
    }
    /* Hide descriptions — Nighttab tiles are name-only. */
    .service-description, [class*="description"] { display: none !important; }
    /* Service icon: large, blue-tinted, centered above the name. */
    .service-card img, .service-card svg, .service-card [class*="icon"] {
      width: 2.4rem !important;
      height: 2.4rem !important;
      filter: brightness(1.1) saturate(1.3);
    }
    /* Bookmark abbr letter-tiles: bold blue letters, no background — to
       match the Nighttab "AZ / GM / DR" style of plain large initials. */
    .bookmark-card .bookmark-abbr,
    .bookmark-card [class*="abbr"] {
      background: transparent !important;
      color: var(--accent-bright) !important;
      font-weight: 800 !important;
      font-size: 1.6rem !important;
      letter-spacing: 0.02em;
      width: auto !important;
      height: auto !important;
      padding: 0 !important;
    }
    /* Tile labels. */
    .service-name, .bookmark-text, [class*="service"] [class*="name"] {
      font-weight: 500 !important;
      font-size: 0.85rem !important;
      color: var(--fg-dim) !important;
      text-align: center !important;
    }
    /* Hide version badge and footer chrome. */
    [class*="version"], footer { display: none !important; }
  '';
  customJs = pkgs.writeText "homepage-custom.js" "";

  # Service cards. Group → list of {name, href, icon, description, …}.
  servicesYaml = pkgs.writeText "homepage-services.yaml" (builtins.toJSON [
    {
      Diagrams = [
        {
          Excalidraw = {
            icon = "excalidraw";
            href = "http://localhost:8899";
            description = "Virtual whiteboard for hand-drawn diagrams";
          };
        }
        {
          "Mermaid Live" = {
            icon = "mermaid";
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
            icon = "portainer";
            href = "https://localhost:9443";
            description = "Container management UI";
          };
        }
        {
          SearXNG = {
            icon = "searxng";
            href = "http://localhost:8888";
            description = "Privacy-respecting metasearch";
          };
        }
        {
          Qdrant = {
            icon = "qdrant";
            href = "http://localhost:6333/dashboard";
            description = "Vector database + dashboard";
          };
        }
        {
          Linkding = {
            icon = "linkding";
            href = "http://localhost:9090";
            description = "Self-hosted bookmark manager";
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

  # Widget row shown at the top of the dashboard. Nighttab-style: just
  # datetime + search inline, no greeting.
  widgetsYaml = pkgs.writeText "homepage-widgets.yaml" (builtins.toJSON [
    {
      datetime = {
        text_size = "l";
        format = {
          # Compact "15:27 25 Apr" style closer to Nighttab's header.
          dateStyle = "medium";
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
        "${customCss}:/app/config/custom.css:ro,z"
        "${customJs}:/app/config/custom.js:ro,z"
      ];
      environments = {
        # v0.9+ enforces an allowed-hosts allowlist. Cover the three ways the
        # dashboard gets reached in practice.
        HOMEPAGE_ALLOWED_HOSTS = "localhost:8880,127.0.0.1:8880,host.containers.internal:8880";
      };
      labels = [
        "io.containers.autoupdate=registry"
      ];
      # The upstream homepage image ships a HEALTHCHECK that podman wires up
      # as an auto-spawned systemd timer. Its first probe fires before Next.js
      # finishes binding to :3000, exits "starting" (status 1), and breaks
      # nixos-rebuild's switch-to-configuration. We don't consume the health
      # signal anywhere, so just turn it off.
      healthCmd = "none";
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
