# Glance — glanceapp/glance dashboard for all self-hosted services.
# Reachable at http://localhost:8880. Runs on the host network namespace so
# the monitor widgets below can probe each `http://localhost:PORT` target
# directly (otherwise `localhost` inside the container resolves to the
# container itself and every site shows ERROR). With network=host there is
# no port publishing — glance binds :8880 on the host directly via
# `server.port` below. Port kept stable across the homepage→glance swap so
# the Firefox start-up homepage and `Self-hosted › Dashboard` managed
# bookmark in modules/common/programs/browsers/firefox/default.nix keep
# working.
#
# Config is generated from Nix (writeText + builtins.toJSON — JSON is a valid
# YAML subset, so glance's yaml.v3 parser accepts it) and mounted read-only
# into /app/config/glance.yml. Because the config is generated, you cannot
# write YAML comments — instead, widgets you don't want yet are commented out
# at the Nix-attr level (`# { ... }`), so toJSON never sees them. Each
# commented block is preceded by a short note explaining what enabling it
# requires (token / URL / sops key). To re-enable, uncomment the block and
# nixos-rebuild switch.
#
# ──────────────────────────────────────────────────────────────────────────
# Secret-gated widgets read sops via glance-env.service → /run/glance/env →
# container EnvironmentFile → ${VAR} expansion in glance.yml at start. Wired:
#   • GH_TOKEN                    ← glance_github_token
#   • KARAKEEP_API_KEY            ← karakeep_admin_api_key (reused)
#   • GCAL_ICAL_URL               ← glance_gcal_ical_url
#   • SPEEDTEST_URL               ← inline 'http://localhost:8765'
#   • SPEEDTEST_TRACKER_API_TOKEN ← speedtest_tracker_api_token
#   • TRAKT_API_KEY               ← trakt_api_key (OAuth Client ID)
#   • TRAKT_ACCESS_TOKEN          ← trakt_access_token (rotate every ~3mo via scripts/trakt-auth.sh)
#   • TRAKT_USERNAME              ← trakt_username (plaintext)
#   • TMDB_API_KEY                ← tmdb_api_key (themoviedb.org v3)
# Not wired:
#   • CRONICLE_API_KEY — Cronicle uses admin/admin session login, no API key
#
# To activate a secret-gated widget: uncomment the widget block below and
# `scripts/nix_switch`. Empty values are tolerated: the env-file gets `KEY=`
# and the widget fails-soft (custom-api tiles 401, etc.).
#
# Trakt OAuth bootstrap (required for /calendars/my/...): run
# `TRAKT_CLIENT_ID=... TRAKT_CLIENT_SECRET=... scripts/trakt-auth.sh`, paste
# the printed access_token into sops as `trakt_access_token`. See script
# header for full walkthrough. Refresh by re-running the script (no automated
# refresh service in v1).
# ──────────────────────────────────────────────────────────────────────────
{
  pkgs,
  config,
  ...
}: let
  sopsPath = name: config.sops.secrets.${name}.path;

  # Home-page tile template for the service-bridge backend. Backed by the
  # service-bridge daemon (modules/containers/service-bridge) which combines
  # `systemctl is-active` with an HTTP probe to produce tri-state status.
  # The Containers page is rendered via iframe directly from the bridge —
  # see ./service-bridge/bridge.py:_UI_HTML — because Go html/template's
  # autoescaping breaks JS event handlers inside onclick attributes.
  serviceBridgeHomeTemplate = import ./service-bridge/widget-home.nix;

  # Common bookmark links reused on Home + Self-hosted pages.
  developerLinks = [
    {
      title = "GitHub";
      url = "https://github.com/Killua7362";
    }
    {
      title = "NixOS Search";
      url = "https://search.nixos.org/packages";
    }
    {
      title = "Home Manager Options";
      url = "https://home-manager-options.extranix.com/";
    }
    {
      title = "Flake";
      url = "https://github.com/Killua7362/killuanix";
    }
  ];

  docsLinks = [
    {
      title = "Arkenfox Wiki";
      url = "https://github.com/arkenfox/user.js/wiki";
    }
    {
      title = "Hyprland Wiki";
      url = "https://wiki.hyprland.org/";
    }
    {
      title = "Claude Docs";
      url = "https://docs.claude.com/";
    }
  ];

  selfHostedLinks = [
    {
      title = "Glance";
      url = "http://localhost:8880";
    }
    {
      title = "Portainer";
      url = "https://localhost:9443";
    }
    {
      title = "Karakeep";
      url = "http://localhost:9090";
    }
    {
      title = "FreshRSS";
      url = "http://localhost:8083";
    }
    {
      title = "Cronicle";
      url = "http://localhost:3012";
    }
    {
      title = "SearXNG";
      url = "http://localhost:8888";
    }
  ];

  # ─── Trakt + TMDB shared templates ─────────────────────────────────────
  # Trakt's `trakt-api-version: 2` header is required on every call. The
  # `Authorization: Bearer ...` header is only needed for /sync/* and
  # /calendars/my/* — trending endpoints work with just the API key. Empty
  # ${TRAKT_ACCESS_TOKEN} fails-soft to a 401 tile.
  traktHeaders = {
    "trakt-api-key" = "\${TRAKT_API_KEY}";
    "trakt-api-version" = "2";
    "User-Agent" = "Glance";
    Accept = "application/json";
  };
  traktAuthHeaders =
    traktHeaders
    // {
      Authorization = "Bearer \${TRAKT_ACCESS_TOKEN}";
    };

  # Trakt "recently watched" history widget. Adapted from the community
  # widgets repo (https://github.com/glanceapp/community-widgets/tree/main/widgets/trakt)
  # with Bearer auth so it works on private profiles. Each item makes a TMDB
  # subrequest via `newRequest` to enrich the poster — failing TMDB calls just
  # render the title without a poster (no template crash).
  traktHistoryTemplate = ''
    {{ $imageUrlBase := "https://image.tmdb.org/t/p/w185" }}
    <ul class="list list-gap-10 collapsible-container" data-collapse-after="5">
    {{ range .JSON.Array "" }}
      {{ $mediaType := .String "type" }}
      {{ $tmdbID := "" }}
      {{ $tmdbPageUrl := "" }}
      {{ $posterUrl := "" }}
      {{ if eq $mediaType "episode" }}
        {{ $tmdbID = .String "show.ids.tmdb" }}
        {{ $tmdbPageUrl = concat "https://www.themoviedb.org/tv/" $tmdbID }}
        {{ if $tmdbID }}
          {{ $tmdbData := newRequest (concat "https://api.themoviedb.org/3/tv/" $tmdbID "?api_key=" "''${TMDB_API_KEY}") | withHeader "Accept" "application/json" | getResponse }}
          {{ if $tmdbData }}
            {{ $p := $tmdbData.JSON.String "poster_path" }}
            {{ if $p }}{{ $posterUrl = concat $imageUrlBase $p }}{{ end }}
          {{ end }}
        {{ end }}
      {{ else }}
        {{ $tmdbID = .String "movie.ids.tmdb" }}
        {{ $tmdbPageUrl = concat "https://www.themoviedb.org/movie/" $tmdbID }}
        {{ if $tmdbID }}
          {{ $tmdbData := newRequest (concat "https://api.themoviedb.org/3/movie/" $tmdbID "?api_key=" "''${TMDB_API_KEY}") | withHeader "Accept" "application/json" | getResponse }}
          {{ if $tmdbData }}
            {{ $p := $tmdbData.JSON.String "poster_path" }}
            {{ if $p }}{{ $posterUrl = concat $imageUrlBase $p }}{{ end }}
          {{ end }}
        {{ end }}
      {{ end }}
      <li class="flex items-center gap-10">
        <a href="{{ $tmdbPageUrl }}" target="_blank">
          <img src="{{ $posterUrl }}" alt="" style="border-radius: 5px; min-width: 4rem; max-width: 4rem;" class="card">
        </a>
        <div class="flex-1">
          <a href="{{ $tmdbPageUrl }}" target="_blank">
            <p class="color-positive size-h5">{{ .String "show.title" }}{{ .String "movie.title" }}</p>
          </a>
          {{ if eq $mediaType "episode" }}
            <p class="size-h6">S{{ .String "episode.season" }}E{{ .String "episode.number" }} — {{ .String "episode.title" }}</p>
          {{ end }}
          <p class="size-h6 color-subdue" {{ .String "watched_at" | parseRelativeTime "2006-01-02T15:04:05.000Z" }}></p>
        </div>
      </li>
    {{ end }}
    </ul>
  '';

  # Auto-fill compact card grid for trending. Small poster left, title+year
  # right. `auto-fill` + minmax fits as many cards per row as the column
  # width allows. Type via `.Options.String "mediaType"` so movies + shows
  # share the template. Same TMDB enrichment pattern as the history widget.
  traktTrendingTemplate = ''
    {{ $imageUrlBase := "https://image.tmdb.org/t/p/w342" }}
    {{ $mediaType := .Options.StringOr "mediaType" "movie" }}
    <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(13rem, 18rem)); justify-content: start; gap: 0.8rem;">
    {{ range .JSON.Array "" }}
      {{ $tmdbID := "" }}
      {{ $title := "" }}
      {{ $year := "" }}
      {{ $tmdbPageUrl := "" }}
      {{ if eq $mediaType "movie" }}
        {{ $tmdbID = .String "movie.ids.tmdb" }}
        {{ $title = .String "movie.title" }}
        {{ $year = .String "movie.year" }}
        {{ $tmdbPageUrl = concat "https://www.themoviedb.org/movie/" $tmdbID }}
      {{ else }}
        {{ $tmdbID = .String "show.ids.tmdb" }}
        {{ $title = .String "show.title" }}
        {{ $year = .String "show.year" }}
        {{ $tmdbPageUrl = concat "https://www.themoviedb.org/tv/" $tmdbID }}
      {{ end }}
      {{ $posterUrl := "" }}
      {{ if $tmdbID }}
        {{ $apiPath := "movie" }}
        {{ if ne $mediaType "movie" }}{{ $apiPath = "tv" }}{{ end }}
        {{ $tmdbData := newRequest (concat "https://api.themoviedb.org/3/" $apiPath "/" $tmdbID "?api_key=" "''${TMDB_API_KEY}") | withHeader "Accept" "application/json" | getResponse }}
        {{ if $tmdbData }}
          {{ $p := $tmdbData.JSON.String "poster_path" }}
          {{ if $p }}{{ $posterUrl = concat $imageUrlBase $p }}{{ end }}
        {{ end }}
      {{ end }}
      <a href="{{ $tmdbPageUrl }}" target="_blank" class="card" style="padding: 0.5rem; overflow: hidden; max-width: 18rem; display: flex; flex-direction: column; gap: 0.45rem;">
        <img src="{{ $posterUrl }}" alt="" style="aspect-ratio: 2/3; object-fit: cover; width: 100%; border-radius: 6px;">
        <div style="min-width: 0; padding: 0 0.15rem 0.15rem;">
          <p class="size-h5 color-highlight" style="line-height: 1.2; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">{{ $title }}</p>
          <p class="size-h6 color-subdue">{{ $year }}</p>
        </div>
      </a>
    {{ end }}
    </div>
  '';

  # Upcoming items from /calendars/my/movies + /calendars/my/shows. Each entry
  # has a top-level `first_aired` (ISO 8601) + nested movie/show metadata. We
  # render a tight vertical list — poster + title + airdate.
  traktUpcomingMoviesTemplate = ''
    {{ $imageUrlBase := "https://image.tmdb.org/t/p/w92" }}
    <ul class="list list-gap-10 collapsible-container" data-collapse-after="4">
    {{ range .JSON.Array "" }}
      {{ $tmdbID := .String "movie.ids.tmdb" }}
      {{ $posterUrl := "" }}
      {{ if $tmdbID }}
        {{ $tmdbData := newRequest (concat "https://api.themoviedb.org/3/movie/" $tmdbID "?api_key=" "''${TMDB_API_KEY}") | withHeader "Accept" "application/json" | getResponse }}
        {{ if $tmdbData }}
          {{ $p := $tmdbData.JSON.String "poster_path" }}
          {{ if $p }}{{ $posterUrl = concat $imageUrlBase $p }}{{ end }}
        {{ end }}
      {{ end }}
      <li class="flex items-center gap-10">
        <a href="https://www.themoviedb.org/movie/{{ $tmdbID }}" target="_blank">
          <img src="{{ $posterUrl }}" alt="" style="border-radius: 4px; min-width: 3rem; max-width: 3rem;" class="card">
        </a>
        <div class="flex-1">
          <a href="https://www.themoviedb.org/movie/{{ $tmdbID }}" target="_blank">
            <p class="color-positive size-h6">{{ .String "movie.title" }} ({{ .String "movie.year" }})</p>
          </a>
          <p class="size-h6 color-subdue" {{ .String "released" | parseRelativeTime "2006-01-02" }}></p>
        </div>
      </li>
    {{ end }}
    </ul>
  '';

  traktUpcomingShowsTemplate = ''
    {{ $imageUrlBase := "https://image.tmdb.org/t/p/w92" }}
    <ul class="list list-gap-10 collapsible-container" data-collapse-after="4">
    {{ range .JSON.Array "" }}
      {{ $tmdbID := .String "show.ids.tmdb" }}
      {{ $posterUrl := "" }}
      {{ if $tmdbID }}
        {{ $tmdbData := newRequest (concat "https://api.themoviedb.org/3/tv/" $tmdbID "?api_key=" "''${TMDB_API_KEY}") | withHeader "Accept" "application/json" | getResponse }}
        {{ if $tmdbData }}
          {{ $p := $tmdbData.JSON.String "poster_path" }}
          {{ if $p }}{{ $posterUrl = concat $imageUrlBase $p }}{{ end }}
        {{ end }}
      {{ end }}
      <li class="flex items-center gap-10">
        <a href="https://www.themoviedb.org/tv/{{ $tmdbID }}" target="_blank">
          <img src="{{ $posterUrl }}" alt="" style="border-radius: 4px; min-width: 3rem; max-width: 3rem;" class="card">
        </a>
        <div class="flex-1">
          <a href="https://www.themoviedb.org/tv/{{ $tmdbID }}" target="_blank">
            <p class="color-positive size-h6">{{ .String "show.title" }}</p>
          </a>
          <p class="size-h6">S{{ .String "episode.season" }}E{{ .String "episode.number" }} — {{ .String "episode.title" }}</p>
          <p class="size-h6 color-subdue" {{ .String "first_aired" | parseRelativeTime "2006-01-02T15:04:05.000Z" }}></p>
        </div>
      </li>
    {{ end }}
    </ul>
  '';

  # Speedtest Tracker — copied from
  # https://github.com/glanceapp/community-widgets/tree/main/widgets/speedtest-tracker
  # SVG up/down arrows trimmed to text symbols for compactness.
  speedtestTemplate = ''
    {{ $stats := .Subrequest "stats" }}
    <div class="flex justify-between text-center margin-block-3">
      <div>
        {{ $dlChange := percentChange (.JSON.Float "data.download_bits") ($stats.JSON.Float "data.download.avg_bits") }}
        <div class="size-small {{ if gt $dlChange 0.0 }}color-positive{{ else if lt $dlChange 0.0 }}color-negative{{ else }}color-primary{{ end }}">
          {{ $dlChange | printf "%+.1f%%" }}{{ if gt $dlChange 0.0 }} ↑{{ else if lt $dlChange 0.0 }} ↓{{ end }}
        </div>
        <div class="color-highlight size-h3">{{ .JSON.Float "data.download_bits" | mul 0.000001 | printf "%.1f" }}</div>
        <div class="size-h6">DOWN Mb/s</div>
      </div>
      <div>
        {{ $ulChange := percentChange (.JSON.Float "data.upload_bits") ($stats.JSON.Float "data.upload.avg_bits") }}
        <div class="size-small {{ if gt $ulChange 0.0 }}color-positive{{ else if lt $ulChange 0.0 }}color-negative{{ else }}color-primary{{ end }}">
          {{ $ulChange | printf "%+.1f%%" }}{{ if gt $ulChange 0.0 }} ↑{{ else if lt $ulChange 0.0 }} ↓{{ end }}
        </div>
        <div class="color-highlight size-h3">{{ .JSON.Float "data.upload_bits" | mul 0.000001 | printf "%.1f" }}</div>
        <div class="size-h6">UP Mb/s</div>
      </div>
      <div>
        {{ $pChange := percentChange (.JSON.Float "data.ping") ($stats.JSON.Float "data.ping.avg") }}
        <div class="size-small {{ if gt $pChange 0.0 }}color-negative{{ else if lt $pChange 0.0 }}color-positive{{ else }}color-primary{{ end }}">
          {{ $pChange | printf "%+.1f%%" }}{{ if lt $pChange 0.0 }} ↓{{ else if gt $pChange 0.0 }} ↑{{ end }}
        </div>
        <div class="color-highlight size-h3">{{ .JSON.Float "data.ping" | printf "%.0f" }}</div>
        <div class="size-h6">PING ms</div>
      </div>
    </div>
  '';

  # Favorites — multi-group bookmarks. Glance auto-flows groups into columns
  # when the widget sits in a `full` column, matching the reference dashboard
  # (Dev/Social/Media layout). Icon strings use Glance's `si:` (Simple
  # Icons) prefix; verify each name at https://simpleicons.org/.
  favoriteGroups = [
    {
      title = "Dev";
      links = [
        {
          title = "GitHub";
          url = "https://github.com/Killua7362";
          icon = "si:github";
        }
        {
          title = "Gmail";
          url = "https://mail.google.com/";
          icon = "si:gmail";
        }
        {
          title = "NixOS Search";
          url = "https://search.nixos.org/packages";
          icon = "si:nixos";
        }
      ];
    }
    {
      title = "Social";
      links = [
        {
          title = "YouTube";
          url = "https://www.youtube.com/";
          icon = "si:youtube";
        }
        {
          title = "Reddit";
          url = "https://www.reddit.com/";
          icon = "si:reddit";
        }
        {
          title = "Twitch";
          url = "https://www.twitch.tv/";
          icon = "si:twitch";
        }
      ];
    }
    {
      title = "Media";
      links = [
        {
          title = "Trakt";
          url = "https://trakt.tv/";
          icon = "si:trakt";
        }
        {
          title = "TMDB";
          url = "https://www.themoviedb.org/";
          icon = "si:themoviedatabase";
        }
      ];
    }
  ];

  # ─── Pages ────────────────────────────────────────────────────────────
  homePage = {
    name = "Home";
    columns = [
      # ── Left column ────────────────────────────────────────────────
      {
        size = "small";
        widgets = [
          {
            type = "clock";
            "hour-format" = "24h";
            timezones = [
              {
                timezone = "Asia/Kolkata";
                label = "Sirsi";
              }
              {
                timezone = "UTC";
                label = "UTC";
              }
              {
                timezone = "America/Los_Angeles";
                label = "Pacific";
              }
            ];
          }
          {
            type = "weather";
            location = "Sirsi, Karnataka, India";
            units = "metric";
            "hour-format" = "24h";
          }
        ];
      }
      # ── Center column ──────────────────────────────────────────────
      {
        size = "full";
        widgets = [
          {
            type = "search";
            "search-engine" = "http://localhost:8888/search?q={QUERY}";
            "new-tab" = true;
            bangs = [
              {
                title = "YouTube";
                shortcut = "!yt";
                url = "https://www.youtube.com/results?search_query={QUERY}";
              }
              {
                title = "GitHub";
                shortcut = "!gh";
                url = "https://github.com/search?q={QUERY}&type=repositories";
              }
              {
                title = "Trakt";
                shortcut = "!tk";
                url = "https://trakt.tv/search?query={QUERY}";
              }
              {
                title = "TMDB";
                shortcut = "!tm";
                url = "https://www.themoviedb.org/search?query={QUERY}";
              }
              {
                title = "Nix packages";
                shortcut = "!np";
                url = "https://search.nixos.org/packages?query={QUERY}";
              }
              {
                title = "Nix options";
                shortcut = "!no";
                url = "https://search.nixos.org/options?query={QUERY}";
              }
              {
                title = "HM options";
                shortcut = "!hm";
                url = "https://home-manager-options.extranix.com/?query={QUERY}";
              }
            ];
          }
          {
            type = "bookmarks";
            title = "Favorites";
            groups = favoriteGroups;
          }
          # Services tiles — sourced from service-bridge so the status is
          # tri-state (up/down/error) rather than the binary HTTP probe the
          # native monitor widget does. No control buttons here; those live
          # on the Containers page below.
          {
            type = "custom-api";
            title = "Services";
            cache = "30s";
            url = "http://localhost:8770/services?homepage_only=true";
            template = serviceBridgeHomeTemplate;
          }
          # Feeds — served from service-bridge so the widget can include a
          # Refresh button and scroll internally. Replaces the old Feeds tab.
          # Feed URLs live in bridge.py:FEEDS.
          {
            type = "iframe";
            source = "http://localhost:8770/feeds";
            height = 600;
          }
        ];
      }
      # ── Right column ───────────────────────────────────────────────
      {
        size = "small";
        widgets = [
          {
            type = "custom-api";
            title = "Internet";
            "title-url" = "\${SPEEDTEST_URL}";
            cache = "1h";
            url = "\${SPEEDTEST_URL}/api/v1/results/latest";
            headers = {
              Authorization = "Bearer \${SPEEDTEST_TRACKER_API_TOKEN}";
              Accept = "application/json";
            };
            subrequests = {
              stats = {
                url = "\${SPEEDTEST_URL}/api/v1/stats";
                headers = {
                  Authorization = "Bearer \${SPEEDTEST_TRACKER_API_TOKEN}";
                  Accept = "application/json";
                };
              };
            };
            template = speedtestTemplate;
          }
          {
            type = "calendar";
            "first-day-of-week" = "monday";
          }
        ];
      }
    ];
  };

  # ── Media page (Trakt + TMDB) ─────────────────────────────────────────
  # Trakt's /calendars/my/<type> URL accepts an optional [/start_date[/days]]
  # tail, where start_date MUST be YYYY-MM-DD — literal "today" returns 400.
  # Glance can't substitute the current date into a URL, so we omit the tail
  # and accept Trakt's default 7-day window starting today.
  mediaPage = {
    name = "Media";
    columns = [
      {
        size = "small";
        widgets = [
          {
            type = "custom-api";
            title = "Recently watched";
            "title-url" = "https://trakt.tv/users/\${TRAKT_USERNAME}/history";
            cache = "10m";
            url = "https://api.trakt.tv/users/\${TRAKT_USERNAME}/history";
            parameters = {
              limit = "10";
            };
            headers = traktAuthHeaders;
            template = traktHistoryTemplate;
          }
          {
            type = "custom-api";
            title = "Upcoming movies";
            "title-url" = "https://trakt.tv/calendars/my/movies";
            cache = "6h";
            url = "https://api.trakt.tv/calendars/my/movies";
            headers = traktAuthHeaders;
            template = traktUpcomingMoviesTemplate;
          }
          {
            type = "custom-api";
            title = "Upcoming TV";
            "title-url" = "https://trakt.tv/calendars/my/shows";
            cache = "1h";
            url = "https://api.trakt.tv/calendars/my/shows";
            headers = traktAuthHeaders;
            template = traktUpcomingShowsTemplate;
          }
        ];
      }
      {
        size = "full";
        widgets = [
          {
            type = "custom-api";
            title = "Trending movies";
            "title-url" = "https://trakt.tv/movies/trending";
            cache = "1h";
            url = "https://api.trakt.tv/movies/trending";
            parameters = {
              limit = "12";
            };
            headers = traktHeaders;
            options = {
              mediaType = "movie";
            };
            template = traktTrendingTemplate;
          }
          {
            type = "custom-api";
            title = "Trending shows";
            "title-url" = "https://trakt.tv/shows/trending";
            cache = "1h";
            url = "https://api.trakt.tv/shows/trending";
            parameters = {
              limit = "12";
            };
            headers = traktHeaders;
            options = {
              mediaType = "show";
            };
            template = traktTrendingTemplate;
          }
        ];
      }
    ];
  };

  devPage = {
    name = "Dev";
    columns = [
      {
        size = "full";
        widgets = [
          {
            type = "releases";
            token = "\${GH_TOKEN}";
            repositories = [
              "nixos/nixpkgs"
              "nix-community/home-manager"
              "glanceapp/glance"
              "hyprwm/Hyprland"
              "neovim/neovim"
              "anthropics/claude-code"
            ];
          }
          # ── Repository — open PRs + recent commits on your flake ────────
          # Same GH_TOKEN need as `releases` above.
          # {
          #   type = "repository";
          #   repository = "Killua7362/killuanix";
          #   token = "\${GH_TOKEN}";
          #   "pull-requests-limit" = 5;
          #   "issues-limit" = 5;
          #   "commits-limit" = 5;
          # }
          # ── Change-detection.io ─────────────────────────────────────────
          # If you run changedetection.io as a future container, point its
          # API here for "watched page diffed today" tiles.
          # {
          #   type = "change-detection";
          #   "instance-url" = "http://localhost:5000";
          #   token = "\${CHANGEDETECTION_API_KEY}";
          # }
        ];
      }
    ];
  };

  # Containers page — the full quadlet fleet with tri-state status and
  # start/stop/restart buttons. Powered by the service-bridge daemon
  # (modules/containers/service-bridge). Slug `/containers` is added to the
  # `pages` list below; the home-page Services tile widget covers the 8 hero
  # entries (without buttons).
  containersPage = {
    name = "Containers";
    columns = [
      {
        size = "full";
        widgets = [
          # Embedded via iframe because glance's custom-api widget runs
          # Go html/template autoescaping over the rendered body — that
          # treats anything inside onclick="..." as a JS string literal
          # rather than executable code, breaking the buttons. The bridge
          # serves a self-contained HTML/JS page at /ui where script tags
          # actually run.
          # Height padded so the iframe's own scrollbar never activates;
          # cross-origin (localhost:8880 vs :8770) blocks JS auto-resize.
          # Bump if you add many more services to ./service-bridge/services.nix.
          {
            type = "iframe";
            source = "http://localhost:8770/ui";
            height = 2800;
          }
        ];
      }
    ];
  };

  # Custom CSS to swap Glance's default JetBrains-Mono for Inter (sans-serif),
  # tighten card padding, and tweak a few spacing details to match the
  # reference dashboard from /r/selfhosted (post 1njon8x). Mounted alongside
  # glance.yml and referenced via theme.custom-css-file.
  glanceCss = pkgs.writeText "glance-custom.css" ''
    @import url("https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap");

    :root {
      --bgf: "Inter", ui-sans-serif, system-ui, -apple-system, sans-serif;
    }
    html, body, .widget, .widget-content, .list, .size-h1, .size-h2,
    .size-h3, .size-h4, .size-h5, .size-h6, .size-base, .size-title-base {
      font-family: var(--bgf) !important;
    }
    /* Tighten widget corners for the flat-dark look */
    .widget { border-radius: 8px; }
    /* Slightly softer card borders */
    .widget-content { padding: 1rem 1.25rem; }
    /* Subtler nav underline + brighter active tab */
    .nav-item.nav-item-current { color: hsl(var(--color-primary)); }
  '';

  glanceYml = pkgs.writeText "glance.yml" (builtins.toJSON {
    server = {
      host = "0.0.0.0";
      port = 8880;
    };

    # Reference: r/selfhosted post 1njon8x screenshot palette.
    # Near-black canvas, slightly raised card surface, cyan accent. HSL triples
    # (hue saturation lightness — no commas, spaces only).
    theme = {
      "background-color" = "220 10 6";
      "contrast-multiplier" = 1.15;
      "text-saturation-multiplier" = 0.9;
      "primary-color" = "170 75 65";
      "positive-color" = "140 60 55";
      "negative-color" = "0 70 60";
      "custom-css-file" = "/app/config/custom.css";
    };

    pages = [
      homePage
      mediaPage
      containersPage
      devPage
    ];
  });
in {
  virtualisation.quadlet.containers.glance = {
    autoStart = true;

    containerConfig = {
      image = "docker.io/glanceapp/glance:latest";
      networks = ["host"];
      volumes = [
        "${glanceYml}:/app/config/glance.yml:ro,z"
        "${glanceCss}:/app/config/custom.css:ro,z"
      ];
      labels = [
        "io.containers.autoupdate=registry"
      ];
      environmentFiles = ["/run/glance/env"];
    };

    serviceConfig = {
      Restart = "always";
      TimeoutStartSec = 300;
    };

    unitConfig = {
      Description = "Glance - Self-hosted service dashboard";
      After = [
        "network-online.target"
        "podman.socket"
        "glance-env.service"
      ];
      Requires = [
        "podman.socket"
        "glance-env.service"
      ];
    };
  };

  # Assemble /run/glance/env from sops-decrypted secrets before the container
  # starts. Mirrors the litellm-env pattern. Empty values are intentional —
  # widgets that don't have a populated key just get `KEY=` and fail-soft.
  systemd.services.glance-env = {
    description = "Assemble Glance env file from sops secrets";
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      RuntimeDirectory = "glance";
      RuntimeDirectoryMode = "0700";
    };
    script = ''
      read_secret() {
        local path="$1"
        [ -f "$path" ] && cat "$path" || echo ""
      }

      umask 077
      {
        printf 'GH_TOKEN=%s\n' "$(read_secret ${sopsPath "glance_github_token"})"
        printf 'KARAKEEP_API_KEY=%s\n' "$(read_secret ${sopsPath "karakeep_admin_api_key"})"
        # CRONICLE_API_KEY intentionally unset — Cronicle module uses
        # admin/admin session login, no long-lived API key in sops.
        printf 'GCAL_ICAL_URL=%s\n' "$(read_secret ${sopsPath "glance_gcal_ical_url"})"
        # ── Home-page media + speed widgets ────────────────────────────
        printf 'SPEEDTEST_URL=%s\n' 'http://localhost:8765'
        printf 'SPEEDTEST_TRACKER_API_TOKEN=%s\n' "$(read_secret ${sopsPath "speedtest_tracker_api_token"})"
        printf 'TRAKT_API_KEY=%s\n' "$(read_secret ${sopsPath "trakt_api_key"})"
        printf 'TRAKT_ACCESS_TOKEN=%s\n' "$(read_secret ${sopsPath "trakt_access_token"})"
        printf 'TRAKT_USERNAME=%s\n' "$(read_secret ${sopsPath "trakt_username"})"
        printf 'TMDB_API_KEY=%s\n' "$(read_secret ${sopsPath "tmdb_api_key"})"
      } > /run/glance/env
    '';
  };
}
