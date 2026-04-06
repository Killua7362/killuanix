{ config
, pkgs
, lib
, inputs
, ...
}: {
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
      url.start_pages = [ "about:blank" ];
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

      # -- Theme: Firefox Natsumi Dark --

      # Completion
      colors.completion.fg = "#d4d4d4";
      colors.completion.odd.bg = "#1e1f2b";
      colors.completion.even.bg = "#19191b";
      colors.completion.category.fg = "#d4d4d4";
      colors.completion.category.bg = "#141416";
      colors.completion.category.border.top = "#2a2a2e";
      colors.completion.category.border.bottom = "#2a2a2e";
      colors.completion.item.selected.fg = "#ffffff";
      colors.completion.item.selected.bg = "#2f3456";
      colors.completion.item.selected.border.top = "#2f3456";
      colors.completion.item.selected.border.bottom = "#2f3456";
      colors.completion.item.selected.match.fg = "#89ceff";
      colors.completion.match.fg = "#89ceff";
      colors.completion.scrollbar.fg = "#3a3a3e";
      colors.completion.scrollbar.bg = "#19191b";

      # Downloads
      colors.downloads.bar.bg = "#19191b";
      colors.downloads.start.fg = "#19191b";
      colors.downloads.start.bg = "#89ceff";
      colors.downloads.stop.fg = "#19191b";
      colors.downloads.stop.bg = "#8aac8b";
      colors.downloads.error.fg = "#d4d4d4";
      colors.downloads.error.bg = "#e2467a";

      # Hints
      colors.hints.fg = "#19191b";
      colors.hints.bg = "#89ceff";
      colors.hints.match.fg = "#e2467a";
      hints.border = "1px solid #19191b";

      # Key hints
      colors.keyhint.fg = "#d4d4d4";
      colors.keyhint.suffix.fg = "#89ceff";
      colors.keyhint.bg = "rgba(25, 25, 27, 0.95)";

      # Messages
      colors.messages.error.fg = "#d4d4d4";
      colors.messages.error.bg = "#e2467a";
      colors.messages.error.border = "#e2467a";
      colors.messages.warning.fg = "#19191b";
      colors.messages.warning.bg = "#aca98a";
      colors.messages.warning.border = "#aca98a";
      colors.messages.info.fg = "#d4d4d4";
      colors.messages.info.bg = "#2a2a2e";
      colors.messages.info.border = "#2a2a2e";

      # Prompts
      colors.prompts.fg = "#d4d4d4";
      colors.prompts.border = "1px solid #3a3a3e";
      colors.prompts.bg = "#1e1f2b";
      colors.prompts.selected.fg = "#ffffff";
      colors.prompts.selected.bg = "#2f3456";

      # Statusbar
      colors.statusbar.normal.fg = "#9a9a9a";
      colors.statusbar.normal.bg = "#19191b";
      colors.statusbar.insert.fg = "#19191b";
      colors.statusbar.insert.bg = "#8aac8b";
      colors.statusbar.passthrough.fg = "#19191b";
      colors.statusbar.passthrough.bg = "#89ceff";
      colors.statusbar.private.fg = "#d4d4d4";
      colors.statusbar.private.bg = "#ac8aac";
      colors.statusbar.command.fg = "#d4d4d4";
      colors.statusbar.command.bg = "#19191b";
      colors.statusbar.command.private.fg = "#d4d4d4";
      colors.statusbar.command.private.bg = "#ac8aac";
      colors.statusbar.caret.fg = "#19191b";
      colors.statusbar.caret.bg = "#89ceff";
      colors.statusbar.caret.selection.fg = "#19191b";
      colors.statusbar.caret.selection.bg = "#89ceff";
      colors.statusbar.progress.bg = "#89ceff";
      colors.statusbar.url.fg = "#9a9a9a";
      colors.statusbar.url.error.fg = "#e2467a";
      colors.statusbar.url.hover.fg = "#89ceff";
      colors.statusbar.url.success.http.fg = "#8aacab";
      colors.statusbar.url.success.https.fg = "#9a9a9a";
      colors.statusbar.url.warn.fg = "#aca98a";

      # Tabs — clean sidebar like Firefox Natsumi
      colors.tabs.bar.bg = "#19191b";
      colors.tabs.indicator.start = "#89ceff";
      colors.tabs.indicator.stop = "#89ceff";
      colors.tabs.indicator.error = "#e2467a";
      colors.tabs.odd.bg = "#19191b";
      colors.tabs.odd.fg = "#8a8a8e";
      colors.tabs.even.bg = "#19191b";
      colors.tabs.even.fg = "#8a8a8e";
      colors.tabs.selected.odd.bg = "#2a2a2e";
      colors.tabs.selected.odd.fg = "#d4d4d4";
      colors.tabs.selected.even.bg = "#2a2a2e";
      colors.tabs.selected.even.fg = "#d4d4d4";
      colors.tabs.pinned.odd.bg = "#19191b";
      colors.tabs.pinned.odd.fg = "#8a8a8e";
      colors.tabs.pinned.even.bg = "#19191b";
      colors.tabs.pinned.even.fg = "#8a8a8e";
      colors.tabs.pinned.selected.odd.bg = "#2a2a2e";
      colors.tabs.pinned.selected.odd.fg = "#d4d4d4";
      colors.tabs.pinned.selected.even.bg = "#2a2a2e";
      colors.tabs.pinned.selected.even.fg = "#d4d4d4";
      tabs.indicator.width = 3;
      tabs.favicons.scale = 1.0;

      # Context menu
      colors.contextmenu.menu.fg = "#d4d4d4";
      colors.contextmenu.menu.bg = "#1e1f2b";
      colors.contextmenu.selected.fg = "#ffffff";
      colors.contextmenu.selected.bg = "#2f3456";
      colors.contextmenu.disabled.fg = "#4a4a4e";
      colors.contextmenu.disabled.bg = "#1e1f2b";

      # -- Fullscreen (match Firefox: no warning) --
      content.fullscreen.window = true;

      # -- Window --
      window.title_format = "{perc}{current_title}{title_sep}qutebrowser";

      # -- Misc (match Firefox prefs) --
      auto_save.session = true; # persist tabs across restarts
      confirm_quit = [ "downloads" ];
      editor.command = [ "kitty" "nvim" "{file}" "-c" "normal {line}G{column0}l" ];
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
