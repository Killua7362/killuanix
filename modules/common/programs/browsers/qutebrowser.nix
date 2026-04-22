{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  p = config.theme.palette;
in {
  programs.qutebrowser = {
    enable = lib.mkDefault (pkgs.stdenv.isLinux);
    loadAutoconfig = false;
    enableDefaultBindings = true;

    # Match Firefox search engines
    searchEngines = {
      "DEFAULT" = "https://www.google.com/search?q={}";
      "g" = "https://www.google.com/search?q={}";
      "searx" = "https://searx.aicampground.com/?q={}";
      "nix" = "https://search.nixos.org/packages?type=packages&query={}";
      "nixopt" = "https://search.nixos.org/options?query={}";
      "nw" = "https://nixos.wiki/index.php?search={}";
      "hm" = "https://home-manager-options.extranix.com/?query={}";
      "gh" = "https://github.com/search?q={}";
      "yt" = "https://www.youtube.com/results?search_query={}";
      "w" = "https://en.wikipedia.org/wiki/Special:Search?search={}";
    };

    settings = {
      # -- Widevine DRM --
      qt.args = [
        "widevine-path=${pkgs.widevine-cdm}/share/google/chrome/WidevineCdm/_platform_specific/linux_x64/libwidevinecdm.so"
        "enable-gpu-rasterization"
        "enable-zero-copy"
        "enable-accelerated-video-decode"
        "enable-accelerated-2d-canvas"
        "ozone-platform-hint=auto"
        "ignore-gpu-blocklist"
        "enable-features=CanvasOopRasterization,UseOzonePlatform,PulseaudioLoopbackForScreenShare"
        "use-pulseaudio"
        "use-gl=egl"
        "num-raster-threads=4"
        "enable-oop-rasterization"
      ];

      # -- Vertical Tabs --
      tabs.position = "left";
      tabs.show = "always";
      tabs.width = 200;
      tabs.last_close = "default-page";
      tabs.new_position.related = "next";
      tabs.new_position.unrelated = "last";
      tabs.select_on_remove = "last-used";
      tabs.close_mouse_button = "none";
      tabs.close_mouse_button_on_bar = "ignore";
      tabs.pinned.frozen = false;
      tabs.pinned.shrink = false;
      tabs.mode_on_change = "restore";
      "tabs.title.format" = "{index}: {audio}{current_title}";
      "tabs.title.format_pinned" = "{index}: {audio}{current_title}";

      # -- Scrolling --
      scrolling.smooth = true;
      scrolling.bar = "never";

      # -- Content / Privacy (match arkenfox + uBlock spirit) --
      content.javascript.clipboard = "access";
      content.notifications.enabled = false;
      content.geolocation = false;
      content.canvas_reading = false; # fingerprinting protection
      content.webgl = false; # arkenfox 4520 disables webgl
      content.cookies.accept = "no-3rdparty";
      content.headers.do_not_track = true;
      content.headers.referer = "same-domain";
      content.private_browsing = false;
      content.dns_prefetch = false;

      # -- Ad blocking (brave adblocker built into qutebrowser) --
      content.blocking.enabled = true;
      content.blocking.method = "both"; # use both adblock + hosts
      content.blocking.adblock.lists = [
        "https://easylist.to/easylist/easylist.txt"
        "https://easylist.to/easylist/easyprivacy.txt"
        "https://big.oisd.nl/"
        "http://sbc.io/hosts/hosts"
        "https://github.com/DandelionSprout/adfilt/raw/master/LegitimateURLShortener.txt"
        "https://raw.githubusercontent.com/gijsdev/ublock-hide-yt-shorts/master/list.txt"
        "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/filters.txt"
        "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/badware.txt"
        "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/privacy.txt"
        "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/quick-fixes.txt"
        "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/unbreak.txt"
        "https://malware-filter.gitlab.io/malware-filter/urlhaus-filter-online.txt"
        "https://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=1&mimetype=plaintext"
      ];

      # -- Downloads --
      downloads.location.directory = "~/Downloads";
      downloads.location.prompt = false;

      # -- URL / Start page --
      url.start_pages = ["about:blank"];
      url.default_page = "about:blank";

      # -- Fonts --
      fonts.default_family = "JetBrainsMono Nerd Font";
      fonts.default_size = "12pt";

      # -- Hints (colemak home row) --
      hints.chars = "arstneio";

      # -- Completion --
      completion.shrink = true;

      # -- Dark mode --
      # preferred_color_scheme tells sites to serve native dark themes.
      # Forced darkmode disabled — it double-inverts sites with native dark
      # themes (e.g. Google) making text invisible, and hurts performance.
      colors.webpage.preferred_color_scheme = "dark";

      # -- Theme: driven by config.theme.palette (theming/palette.nix) --

      # Completion
      colors.completion.fg = p.fg_bright;
      colors.completion.odd.bg = p.surface_alt;
      colors.completion.even.bg = p.surface;
      colors.completion.category.fg = p.fg_bright;
      colors.completion.category.bg = p.surface_low;
      colors.completion.category.border.top = p.surface_high;
      colors.completion.category.border.bottom = p.surface_high;
      colors.completion.item.selected.fg = p.selection_strong;
      colors.completion.item.selected.bg = p.selection;
      colors.completion.item.selected.border.top = p.selection;
      colors.completion.item.selected.border.bottom = p.selection;
      colors.completion.item.selected.match.fg = p.color4;
      colors.completion.match.fg = p.color4;
      colors.completion.scrollbar.fg = p.outline;
      colors.completion.scrollbar.bg = p.surface;

      # Downloads
      colors.downloads.bar.bg = p.surface;
      colors.downloads.start.fg = p.surface;
      colors.downloads.start.bg = p.color4;
      colors.downloads.stop.fg = p.surface;
      colors.downloads.stop.bg = p.color2;
      colors.downloads.error.fg = p.fg_bright;
      colors.downloads.error.bg = p.error;

      # Hints
      colors.hints.fg = p.surface;
      colors.hints.bg = p.color4;
      colors.hints.match.fg = p.error;
      hints.border = "1px solid ${p.surface}";

      # Key hints
      colors.keyhint.fg = p.fg_bright;
      colors.keyhint.suffix.fg = p.color4;
      colors.keyhint.bg = "rgba(25, 25, 27, 0.95)";

      # Messages
      colors.messages.error.fg = p.fg_bright;
      colors.messages.error.bg = p.error;
      colors.messages.error.border = p.error;
      colors.messages.warning.fg = p.surface;
      colors.messages.warning.bg = p.color3;
      colors.messages.warning.border = p.color3;
      colors.messages.info.fg = p.fg_bright;
      colors.messages.info.bg = p.surface_high;
      colors.messages.info.border = p.surface_high;

      # Prompts
      colors.prompts.fg = p.fg_bright;
      colors.prompts.border = "1px solid ${p.outline}";
      colors.prompts.bg = p.surface_alt;
      colors.prompts.selected.fg = p.selection_strong;
      colors.prompts.selected.bg = p.selection;

      # Statusbar
      colors.statusbar.normal.fg = p.fg_dim;
      colors.statusbar.normal.bg = p.surface;
      colors.statusbar.insert.fg = p.surface;
      colors.statusbar.insert.bg = p.color2;
      colors.statusbar.passthrough.fg = p.surface;
      colors.statusbar.passthrough.bg = p.color4;
      colors.statusbar.private.fg = p.fg_bright;
      colors.statusbar.private.bg = p.color5;
      colors.statusbar.command.fg = p.fg_bright;
      colors.statusbar.command.bg = p.surface;
      colors.statusbar.command.private.fg = p.fg_bright;
      colors.statusbar.command.private.bg = p.color5;
      colors.statusbar.caret.fg = p.surface;
      colors.statusbar.caret.bg = p.color4;
      colors.statusbar.caret.selection.fg = p.surface;
      colors.statusbar.caret.selection.bg = p.color4;
      colors.statusbar.progress.bg = p.color4;
      colors.statusbar.url.fg = p.fg_dim;
      colors.statusbar.url.error.fg = p.error;
      colors.statusbar.url.hover.fg = p.color4;
      colors.statusbar.url.success.http.fg = p.color6;
      colors.statusbar.url.success.https.fg = p.fg_dim;
      colors.statusbar.url.warn.fg = p.color3;

      # Tabs — clean sidebar like Firefox Natsumi
      colors.tabs.bar.bg = p.surface;
      colors.tabs.indicator.start = p.color4;
      colors.tabs.indicator.stop = p.color4;
      colors.tabs.indicator.error = p.error;
      colors.tabs.odd.bg = p.surface;
      colors.tabs.odd.fg = p.fg_dimmer;
      colors.tabs.even.bg = p.surface;
      colors.tabs.even.fg = p.fg_dimmer;
      colors.tabs.selected.odd.bg = p.surface_high;
      colors.tabs.selected.odd.fg = p.fg_bright;
      colors.tabs.selected.even.bg = p.surface_high;
      colors.tabs.selected.even.fg = p.fg_bright;
      colors.tabs.pinned.odd.bg = p.surface;
      colors.tabs.pinned.odd.fg = p.fg_dimmer;
      colors.tabs.pinned.even.bg = p.surface;
      colors.tabs.pinned.even.fg = p.fg_dimmer;
      colors.tabs.pinned.selected.odd.bg = p.surface_high;
      colors.tabs.pinned.selected.odd.fg = p.fg_bright;
      colors.tabs.pinned.selected.even.bg = p.surface_high;
      colors.tabs.pinned.selected.even.fg = p.fg_bright;
      tabs.indicator.width = 3;
      tabs.favicons.scale = 1.0;

      # Context menu
      colors.contextmenu.menu.fg = p.fg_bright;
      colors.contextmenu.menu.bg = p.surface_alt;
      colors.contextmenu.selected.fg = p.selection_strong;
      colors.contextmenu.selected.bg = p.selection;
      colors.contextmenu.disabled.fg = p.fg_muted;
      colors.contextmenu.disabled.bg = p.surface_alt;

      # -- Fullscreen (match Firefox: no warning) --
      content.fullscreen.window = true;

      # -- Window --
      window.title_format = "{perc}{current_title}{title_sep}qutebrowser";

      # -- Misc (match Firefox prefs) --
      auto_save.session = true; # persist tabs across restarts
      confirm_quit = ["downloads"];
      editor.command = ["ghostty" "-e" "nvim" "{file}" "-c" "normal {line}G{column0}l"];
    };

    # keyMappings disabled — qutebrowser chains mappings, so cycles like
    # i→k→u→i resolve back to the original key. Using explicit keyBindings instead.
    keyMappings = {};

    keyBindings = {
      normal = {
        # Colemak-DH movement (neio → hjkl)
        "n" = "scroll left";
        "e" = "scroll-px 0 150";
        "i" = "scroll-px 0 -150";
        "o" = "scroll right";

        # Displaced keys
        "h" = "search-next";
        "k" = "undo";
        "u" = "mode-enter insert";
        "y" = "set-cmd-text -s :open";

        # Yank keychains (l = y)
        "ll" = "yank";
        "lt" = "yank title";
        "ld" = "yank domain";
        "lp" = "yank pretty-url";

        # Uppercase
        "N" = "tab-prev";
        "O" = "tab-next";
        "H" = "search-prev";
        "Y" = "set-cmd-text -s :open -t";
        "K" = "undo";
        "L" = "yank";

        # Tab switching by index or title
        "b" = "set-cmd-text -s :tab-select";

        # Navigation
        # "gn" = "back";
        # "go" = "forward";
        "E" = "back";
        "I" = "forward";
        # Half-page scrolling (matching nvim { and })
        "{" = "scroll-page 0 -0.5";
        "}" = "scroll-page 0 0.5";

        # Close/undo tab
        "x" = "tab-close";
        "X" = "undo";

        # Ad block update
        "<Ctrl-u>" = "adblock-update";
      };

      insert = {
        "<Ctrl-[>" = "mode-leave";
      };

      hint = {};

      caret = {
        "n" = "move-to-prev-char";
        "e" = "move-to-next-line";
        "i" = "move-to-prev-line";
        "o" = "move-to-next-char";
        "{" = "scroll up";
        "}" = "scroll down";
      };
    };

    greasemonkey = [];

    extraConfig = ''
      # Unbind default l (scroll right) so ll/lt/ld/lp yank keychains work
      config.unbind('l', mode='normal')

      # Dict settings can't be set via dot-separated keys
      c.tabs.padding = {"top": 6, "bottom": 6, "left": 6, "right": 6}
      c.tabs.indicator.padding = {"top": 4, "bottom": 4, "left": 0, "right": 4}

      # Redirect old reddit (matches old-reddit-redirect extension)
      import qutebrowser.api.interceptor

      def rewrite(request: qutebrowser.api.interceptor.Request):
          url = request.request_url
          if url.host() == "www.reddit.com" or url.host() == "reddit.com":
              url.setHost("old.reddit.com")
              request.redirect(url)

      qutebrowser.api.interceptor.register(rewrite)
    '';
  };
}
