{
  pkgs,
  lib,
  config,
  ...
}: let
  sopsPath = name: config.sops.secrets.${name}.path;
  searxngSettings = pkgs.writeText "settings.yml" (builtins.toJSON {
    use_default_settings = true;

    general = {
      instance_name = "Search";
      debug = false;
      privacypolicy_url = false;
      donation_url = false;
      contact_url = false;
      enable_metrics = false;
    };

    search = {
      safe_search = 0;
      autocomplete = "google";
      default_lang = "en";
      formats = ["html" "json"];
      ban_time_on_fail = 5;
      max_ban_time_on_fail = 120;
    };

    server = {
      port = 8080;
      bind_address = "0.0.0.0";
      secret_key = "ultrasecretkey";
      limiter = false;
      image_proxy = true;
    };

    ui = {
      static_use_hash = true;
      default_theme = "simple";
      theme_args = {
        simple_style = "auto";
      };
      infinite_scroll = true;
      query_in_title = true;
      search_on_category_select = true;
      center_alignment = true;
    };

    engines = [
      # ── Web search (Google-like results) ──
      {
        name = "google";
        engine = "google";
        shortcut = "g";
        disabled = false;
        weight = 1.5;
      }
      {
        name = "startpage";
        engine = "startpage";
        shortcut = "sp";
        disabled = false;
        weight = 1.5;
      }
      {
        name = "mullvad leta";
        engine = "mullvad_leta";
        shortcut = "ml";
        disabled = false;
        weight = 1.3;
      }
      {
        name = "mojeek";
        engine = "mojeek";
        shortcut = "mj";
        disabled = false;
        weight = 1.0;
      }
      {
        name = "bing";
        engine = "bing";
        shortcut = "b";
        disabled = false;
      }
      {
        name = "duckduckgo";
        engine = "duckduckgo";
        shortcut = "ddg";
        disabled = false;
      }
      {
        name = "brave";
        engine = "brave";
        shortcut = "br";
        disabled = false;
      }
      # ── Images ──
      {
        name = "google images";
        engine = "google_images";
        shortcut = "gi";
        disabled = false;
      }
      {
        name = "bing images";
        engine = "bing_images";
        shortcut = "bi";
        disabled = false;
      }
      # ── Videos ──
      {
        name = "google videos";
        engine = "google_videos";
        shortcut = "gv";
        disabled = false;
      }
      {
        name = "invidious";
        engine = "invidious";
        shortcut = "iv";
        disabled = false;
        base_url = "https://invidious.fdn.fr";
      }
      # ── News ──
      {
        name = "google news";
        engine = "google_news";
        shortcut = "gn";
        disabled = false;
      }
      {
        name = "bing news";
        engine = "bing_news";
        shortcut = "bn";
        disabled = false;
      }
      # ── Knowledge / Answers ──
      {
        name = "wikipedia";
        engine = "wikipedia";
        shortcut = "wp";
        disabled = false;
        weight = 1.5;
      }
      {
        name = "wikidata";
        engine = "wikidata";
        shortcut = "wd";
        disabled = false;
      }
      {
        name = "currency";
        engine = "currency_convert";
        shortcut = "cc";
        disabled = false;
      }
      # ── Maps ──
      {
        name = "openstreetmap";
        engine = "openstreetmap";
        shortcut = "osm";
        disabled = false;
      }
      # ── Science / Academic ──
      {
        name = "google scholar";
        engine = "google_scholar";
        shortcut = "gs";
        disabled = false;
      }
      {
        name = "arxiv";
        engine = "arxiv";
        shortcut = "ax";
        disabled = false;
      }
      # ── IT / Dev ──
      {
        name = "github";
        engine = "github";
        shortcut = "gh";
        disabled = false;
        weight = 1.5;
      }
      {
        name = "stackoverflow";
        engine = "stackoverflow";
        shortcut = "so";
        disabled = false;
        weight = 1.5;
      }
      {
        name = "mdn";
        engine = "mdn";
        shortcut = "mdn";
        disabled = false;
        weight = 1.3;
        categories = ["it" "software wikis"];
      }
      {
        name = "readthedocs";
        engine = "readthedocs";
        shortcut = "rtd";
        disabled = false;
        categories = ["it" "software wikis"];
      }
      {
        name = "pypi";
        engine = "pypi";
        shortcut = "pypi";
        disabled = false;
        categories = ["it" "packages"];
      }
      {
        name = "npm";
        engine = "npm";
        shortcut = "npm";
        disabled = false;
        categories = ["it" "packages"];
      }
      {
        name = "arch wiki";
        engine = "archlinux";
        shortcut = "aw";
        disabled = false;
      }
      {
        name = "nixos wiki";
        engine = "mediawiki";
        shortcut = "nw";
        disabled = false;
        base_url = "https://wiki.nixos.org/";
        categories = ["it" "software wikis"];
        search_type = "text";
      }
    ];

    outgoing = {
      request_timeout = 8.0;
      max_request_timeout = 15.0;
      pool_connections = 100;
      pool_maxsize = 20;
      enable_http2 = true;
      keepalive_expiry = 5.0;
      useragent_suffix = "";
    };
  });
in {
  virtualisation.quadlet = {
    containers.searxng = {
      autoStart = true;

      containerConfig = {
        image = "docker.io/searxng/searxng:latest";
        publishPorts = [
          "8888:8080"
        ];
        volumes = [
          "${searxngSettings}:/etc/searxng/settings.yml:ro,z"
        ];
        environments = {
          SEARXNG_BASE_URL = "http://localhost:8888/";
        };
        environmentFiles = ["/run/searxng/env"];
        labels = [
          "io.containers.autoupdate=registry"
        ];
      };

      serviceConfig = {
        Restart = "always";
        TimeoutStartSec = 300;
      };

      unitConfig = {
        Description = "SearXNG - Privacy-respecting metasearch engine";
        After = [
          "network-online.target"
          "searxng-env.service"
        ];
        Requires = ["searxng-env.service"];
      };
    };
  };

  # SearXNG's docker entrypoint substitutes the literal `ultrasecretkey`
  # placeholder in settings.yml with `$SEARXNG_SECRET` at container start.
  # Stage the sops-decrypted secret into an env file the container reads.
  systemd.services.searxng-env = {
    description = "Assemble SearXNG env file from sops secrets";
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      RuntimeDirectory = "searxng";
      RuntimeDirectoryMode = "0700";
    };
    script = ''
      umask 077
      {
        printf 'SEARXNG_SECRET=%s\n' "$(cat ${sopsPath "searxng_secret_key"})"
      } > /run/searxng/env
    '';
  };
}
