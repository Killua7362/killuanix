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
      qt.args = [ "widevine-path=${pkgs.widevine-cdm}/share/google/chrome/WidevineCdm" ];

      # -- Tabs (match Firefox tab behavior) --
      tabs.position = "top";
      tabs.show = "multiple";
      tabs.last_close = "default-page"; # Firefox: don't close window with last tab
      tabs.new_position.related = "next"; # Firefox: insert after current
      tabs.new_position.unrelated = "last";
      tabs.select_on_remove = "last-used"; # Firefox: ctrl+tab sorts by recently used
      tabs.close_mouse_button = "middle";
      tabs.min_width = 90; # Firefox: browser.tabs.tabMinWidth = 90
      tabs.pinned.shrink = true;

      # -- Scrolling --
      scrolling.smooth = true;

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
      colors.webpage.preferred_color_scheme = "dark";
      colors.webpage.darkmode.enabled = true;
      colors.webpage.darkmode.policy.images = "never";

      # -- Fullscreen (match Firefox: no warning) --
      content.fullscreen.window = true;

      # -- Window --
      window.title_format = "{perc}{current_title}{title_sep}qutebrowser";

      # -- Misc (match Firefox prefs) --
      auto_save.session = true; # persist tabs across restarts
      confirm_quit = [ "downloads" ];
      editor.command = [ "kitty" "nvim" "{file}" "-c" "normal {line}G{column0}l" ];
    };

    # keyMappings remaps keys globally before bindings are evaluated.
    # This adapts qutebrowser's vim-style defaults to colemak-dh layout.
    # Pattern from neovim config: n=left, e=down, i=up, o=right
    keyMappings = {
      # movement: neio → hjkl
      "n" = "h"; # left
      "e" = "j"; # down
      "i" = "k"; # up
      "o" = "l"; # right

      # displaced keys get new homes
      "h" = "n"; # next search match (was n)
      "H" = "N"; # prev search match (was N)
      "k" = "u"; # undo (was u)
      "j" = "e"; # end of word (was e)
      "l" = "y"; # yank (was y)
      "u" = "i"; # insert mode (was i)
    };

    keyBindings = {
      normal = {
        # half-page scrolling centered (matching nvim { and })
        "{" = "scroll-page 0 -0.5";
        "}" = "scroll-page 0 0.5";

        # tab navigation using colemak-friendly keys
        "N" = "tab-prev";
        "O" = "tab-next";

        # quick access
        "gn" = "back"; # go back (left in history)
        "go" = "forward"; # go forward (right in history)

        # close/undo tab
        "x" = "tab-close";
        "X" = "undo";

        # open commands
        "y" = "set-cmd-text -s :open"; # open (like nvim 'o' for new line)
        "Y" = "set-cmd-text -s :open -t"; # open in new tab

        # yank url
        "ll" = "yank"; # matches nvim ll = yy

        # ad block update
        "<Ctrl-u>" = "adblock-update";
      };

      insert = {
        # escape insert mode
        "<Ctrl-[>" = "mode-leave";
      };

      hint = { };

      caret = {
        # caret mode movement follows keyMappings automatically
        # add half-page scroll
        "{" = "scroll up";
        "}" = "scroll down";
      };
    };

    # Greasemonkey scripts for SponsorBlock equivalent
    greasemonkey = [
      # You can add userscripts here, e.g. SponsorBlock, Return YouTube Dislikes
      # (pkgs.fetchurl { url = "..."; sha256 = "..."; })
    ];

    extraConfig = ''
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
