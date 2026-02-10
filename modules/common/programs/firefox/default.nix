{
  pkgs,
  lib,
  config,
  inputs,
  self,
  ...
}: let
  firefoxCSS = builtins.fetchGit {
    url = "https://github.com/greeeen-dev/natsumi-browser.git";
    rev = "c65ef3744952664b69a83196f01754d2677b5aa8";
  };

  fschromeconfig = builtins.fetchGit {
    url = "https://github.com/MrOtherGuy/fx-autoconfig";
    rev = "76232083171a8d609bf0258549d843b0536685e1";
  };

mergedChrome = pkgs.runCommand "merged-firefox-chrome" {} ''
  mkdir -p $out

  # Copy fx-autoconfig files
  cp -r ${fschromeconfig}/profile/chrome/* $out/

  # Copy your custom firefoxCSS files (overwrites conflicts)
  cp -r ${firefoxCSS}/* $out/

  # Make files writable
  chmod -R u+w $out

  # Replace the manifest file
  cat > $out/utils/chrome.manifest << 'EOF'
  content userchromejs ./
  content userscripts ../natsumi/scripts/
  skin userstyles classic/1.0 ../CSS/
  content userchrome ../resources/
  content natsumi ../natsumi/
  content natsumi-icons ../natsumi/icons/
  EOF
'';

  in {
  imports = [
    inputs.arkenfox.hmModules.default
  ];

  # home.sessionVariables.DEFAULT_BROWSER = "${Firefox-custom}/bin/firefox";

  home.file.".mozilla/firefox/default/chrome" = {
    source = mergedChrome;
    recursive = true;
  };

  programs.firefox = {
    enable = true;
    arkenfox = {
      enable = true;
    };
    package =  inputs.firefox.packages.${pkgs.stdenv.hostPlatform.system}.firefox-nightly-bin.override {
      extraPrefsFiles = [(builtins.fetchurl {
      url = "https://raw.githubusercontent.com/MrOtherGuy/fx-autoconfig/master/program/config.js";
      sha256 = "1mx679fbc4d9x4bnqajqx5a95y1lfasvf90pbqkh9sm3ch945p40";
    })];
    };
    policies = let
      Lists = [
        "https://big.oisd.nl/"
        "http://sbc.io/hosts/hosts"
        "https://github.com/DandelionSprout/adfilt/raw/master/LegitimateURLShortener.txt"
        "https://gist.githubusercontent.com/Icey-Glitch/d7e365b793bfae21759b750e316d3744/raw/63a1661f3c7e0aac85a8fbb9499fa305d4507e91/ytbetter.txt"
      ];
    in {
      "3rdparty".Extensions = {
        # https://github.com/gorhill/uBlock/blob/master/platform/common/managed_storage.json
        "uBlock0@raymondhill.net".adminSettings = {
          userSettings = {
            uiTheme = "dark";
            uiAccentCustom = true;
            cloudStorageEnabled = lib.mkForce false; # Security liability?
            importedLists = Lists;
            externalLists = lib.concatStringsSep "\n" Lists;
          };
          selectedFilterLists =
            Lists
            ++ [
              "CZE-0"
              "adguard-generic"
              "adguard-annoyance"
              "adguard-social"
              "adguard-spyware-url"
              "easylist"
              "easyprivacy"
              "plowe-0"
              "ublock-abuse"
              "ublock-badware"
              "ublock-filters"
              "ublock-privacy"
              "ublock-quick-fixes"
              "ublock-unbreak"
              "urlhaus-1"
            ];
        };
      };
      Preferences = {
      };
      ExtensionSettings = with builtins;
        let extension = shortId: uuid: {
          name = uuid;
          value = {
            install_url = "https://addons.mozilla.org/en-US/firefox/downloads/latest/${shortId}/latest.xpi";
            installation_mode = "normal_installed";
          };
        };
        in listToAttrs [
          (extension "tree-style-tab" "treestyletab@piro.sakura.ne.jp")
          (extension "ublock-origin" "uBlock0@raymondhill.net")
          (extension "bitwarden-password-manager" "{446900e4-71c2-419f-a6a7-df9c091e268b}")
          (extension "tabliss" "extension@tabliss.io")
          (extension "umatrix" "uMatrix@raymondhill.net")
          (extension "libredirect" "7esoorv3@alefvanoon.anonaddy.me")
          (extension "clearurls" "{74145f27-f039-47ce-a470-a662b129930a}")
        ];
        # To add additional extensions, find it on addons.mozilla.org, find
        # the short ID in the url (like https://addons.mozilla.org/en-US/firefox/addon/!SHORT_ID!/)
        # Then, download the XPI by filling it in to the install_url template, unzip it,
        # run `jq .browser_specific_settings.gecko.id manifest.json` or
        # `jq .applications.gecko.id manifest.json` to get the UUID
    };

    profiles = {
      default =
        {
          name = "default";
          isDefault = true;
          extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
            ublock-origin
            sponsorblock
            clearurls
            old-reddit-redirect
            youtube-redux
            return-youtube-dislikes
            reddit-enhancement-suite
            darkreader
            fastforwardteam
            violentmonkey
          ];

          search = {
            force = true;
            default = "Searx";
            order = [ "Searx" "google" ];
            engines = {
              "Nix Packages" = {
                urls = [
                  {
                    template = "https://search.nixos.org/packages";
                    params = [
                      {
                        name = "type";
                        value = "packages";
                      }
                      {
                        name = "query";
                        value = "{searchTerms}";
                      }
                    ];
                  }
                ];
                icon = "''${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
                definedAliases = [ "@np" ];
              };
              "NixOS Wiki" = {
                urls = [
                  {
                    template = "https://nixos.wiki/index.php?search={searchTerms}";
                  }
                ];
                iconUpdateURL = "https://nixos.wiki/favicon.png";
                updateInterval = 24 * 60 * 60 * 1000; # every day
                definedAliases = [ "@nw" ];
              };
              "Searx" = {
                urls = [
                  {
                    template = "https://searx.aicampground.com/?q={searchTerms}";
                  }
                ];
                iconUpdateURL = "https://nixos.wiki/favicon.png";
                updateInterval = 24 * 60 * 60 * 1000; # every day
                definedAliases = [ "@searx" ];
              };
              "bing".metaData.hidden = true;
              "google".metaData.alias = "@g"; # builtin engines only support specifying one additional alias
            };
          };

          arkenfox = {
            enable = true;
            "0000".enable = true;
            "0100" = {
              enable = true;
              "0102"."browser.startup.page".value = 1;
              "0104"."browser.newtabpage.enabled".value = true;
            };
            "0300" = {
              enable = true;
            };
            "2400" = {
              enable = true;
            };
            "2600" = {
              "2603".enable = true;
            };
            "2800" = {
              "2815".enable = false;
            };
            "4000" = {
              enable = true;
              "4002".enable = true;
              "4002"."privacy.fingerprintingProtection.overrides".value = "+AllTargets,-CSSPrefersColorScheme";
            };
            "4500" = {
              enable = false;
              "4501".enable = true;
              "4504".enable = false; # letter box
              "4510"."browser.display.use_system_colors".value = true; # sys color
              "4520".enable = false; # webgl
            };
          };
          settings =
            {
              fastfox.enable = true;
              peskyfox = {
                enable = true;
                mozilla-ui.enable = false;
              };
            };

          extraConfig = ''
                  user_pref("userChromeJS.persistent_domcontent_callback", true);
                  ////// ⚠️ REQUIRED PREFS

// only required if you're using any of my scripts that use eval().
user_pref("security.allow_unsafe_dangerous_privileged_evil_eval", true);
//// disable telemetry since we're modding firefox
user_pref("toolkit.telemetry.enabled", false);
user_pref("browser.discovery.enabled", false);
user_pref("app.shield.optoutstudies.enabled", false);
user_pref("datareporting.healthreport.documentServerURI", "http://%(server)s/healthreport/");
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionPolicyBypassNotification", true);
user_pref("browser.crashReports.unsubmittedCheck.autoSubmit2", false);
//// make the theme work properly
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("userChromeJS.enabled", true);  // Add this if missing
user_pref("browser.proton.places-tooltip.enabled", true);
user_pref("layout.css.moz-document.content.enabled", true);
//// eliminate the blank white window during startup
user_pref("browser.startup.blankWindow", false);
user_pref("browser.startup.preXulSkeletonUI", false);
////
// required for icons with data URLs
user_pref("svg.context-properties.content.enabled", true);
// required for acrylic gaussian blur
user_pref("layout.css.backdrop-filter.enabled", true);
// enable browser dark mode
user_pref("ui.systemUsesDarkTheme", 1);
// enable content dark mode
user_pref("layout.css.prefers-color-scheme.content-override", 0);
//// avoid native styling
user_pref("browser.display.windows.non_native_menus", 1);
user_pref("widget.content.allow-gtk-dark-theme", true);
// make sure the tab bar is in the titlebar on Linux
user_pref("browser.tabs.inTitlebar", 1);
////
// avoid custom menulist/select styling
user_pref("dom.forms.select.customstyling", false);
// keep "all tabs" menu available at all times, useful for all tabs menu
// expansion pack
user_pref("browser.tabs.tabmanager.enabled", true);
// disable urlbar result group labels since we don't use them
user_pref("browser.urlbar.groupLabels.enabled", false);
// allow urlbar result menu buttons without slowing down tabbing through results
user_pref("browser.urlbar.resultMenu.keyboardAccessible", false);
// Background for selected <option> elements and others
user_pref("ui.selecteditem", "#2F3456");
// Text color for selected <option> elements and others
user_pref("ui.selecteditemtext", "#FFFFFFCC");
//// Tooltip colors (only relevant if userChrome.ag.css somehow fails to apply,
//// but doesn't hurt)
user_pref("ui.infotext", "#FFFFFF");
user_pref("ui.infobackground", "#hsl(233, 36%, 11%)");
////

// ⚠️ REQUIRED on macOS
user_pref("widget.macos.native-context-menus", false);

////// ✨ RECOMMENDED PREFS

//// allow installing the unsigned search extensions. the localized search
//// extensions currently can't be signed because of
//// https://github.com/mozilla/addons-linter/issues/3911 so to use them, we
//// must disable the signature requirement and go to about:addons > gear icon >
//// install addon from file > find the .zip file
user_pref("xpinstall.signatures.required", false);
user_pref("extensions.autoDisableScopes", 0);
//// functionality oriented prefs
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("browser.display.use_system_colors", false);
user_pref("browser.privatebrowsing.enable-new-indicator", false);
user_pref("accessibility.mouse_focuses_formcontrol", 0);
user_pref("browser.tabs.tabMinWidth", 90);
user_pref("browser.urlbar.accessibility.tabToSearch.announceResults", false);
// disable large urlbar suggestions for now. they are styled so this is not
// required, but I don't find them useful since they only seem to appear when
// the urlbar is empty and search engine is set to google.
user_pref("browser.urlbar.richSuggestions.featureGate", false);
// but enable the rich one-line suggestions that appear when typing long search
// terms and guess an end to the sentence
user_pref("browser.urlbar.richSuggestions.tail", false);
user_pref("browser.urlbar.suggest.quicksuggest.nonsponsored", false);
user_pref("browser.urlbar.suggest.quicksuggest.sponsored", false);
user_pref("browser.urlbar.trimURLs", false);
// hide fullscreen enter/exit warning
user_pref("full-screen-api.transition-duration.enter", "0 0");
user_pref("full-screen-api.transition-duration.leave", "0 0");
user_pref("full-screen-api.warning.delay", -1);
user_pref("full-screen-api.warning.timeout", 0);
// whether to show content dialogs within tabs or above tabs
user_pref("prompts.contentPromptSubDialog", true);
// when using the keyboard to navigate menus, skip past disabled items
user_pref("ui.skipNavigatingDisabledMenuItem", 1);
user_pref("ui.prefersReducedMotion", 0);
// reduce the delay before showing submenus (e.g. View > Toolbars)
user_pref("ui.submenuDelay", 100);
// the delay before a tooltip appears when hovering an element (default 300ms)
user_pref("ui.tooltipDelay", 300);
// should pressing the Alt key alone focus the menu bar?
user_pref("ui.key.menuAccessKeyFocuses", false);
// reduce update frequency
user_pref("app.update.suppressPrompts", true);
////

//// style oriented prefs
// use GTK style for in-content scrollbars
user_pref("widget.non-native-theme.scrollbar.style", 2);
//// set the scrollbar style and width
user_pref("widget.non-native-theme.win.scrollbar.use-system-size", false);
user_pref("widget.non-native-theme.scrollbar.size.override", 11);
user_pref("widget.non-native-theme.gtk.scrollbar.thumb-size", "0.818");
//// base color scheme prefs
user_pref("browser.theme.content-theme", 0);
user_pref("browser.theme.toolbar-theme", 0);
// set the default background color for color-scheme: dark. see it for example
// on about:blank
user_pref("browser.display.background_color.dark", "#19191b");
//// selection/highlight colors
user_pref("ui.highlight", "hsla(245, 100%, 70%, 0.55)");
user_pref("ui.highlighttext", "#ffffff");
// window inactive selection/highlight colors
user_pref("ui.textSelectDisabledBackground", "hsla(243, 35%, 65%, 0.45)");
//// findbar highlight and selection colors, match --global-selection-bgcolor
user_pref("ui.textHighlightBackground", "hsla(245, 100%, 70%, 0.55)");
user_pref("ui.textHighlightForeground", "#FFFFFF");
user_pref("ui.textSelectAttentionBackground", "hsla(335, 100%, 60%, 0.65)");
user_pref("ui.textSelectAttentionForeground", "#FFFFFF");
//// spell check style
user_pref("ui.SpellCheckerUnderline", "#E2467A");
user_pref("ui.SpellCheckerUnderlineStyle", 1);
//// IME style (for example when typing pinyin or hangul)
user_pref("ui.IMERawInputBackground", "#000000");
user_pref("ui.IMESelectedRawTextBackground", "hsla(245, 100%, 70%, 0.55)");
////
// about:reader dark mode
user_pref("reader.color_scheme", "dark");

//// font settings
user_pref("layout.css.font-visibility.private", 3);
user_pref("layout.css.font-visibility.resistFingerprinting", 3);
////

//// windows font settings - does nothing on macOS or linux
user_pref("gfx.font_rendering.cleartype_params.cleartype_level", 100);
user_pref("gfx.font_rendering.cleartype_params.force_gdi_classic_for_families", "");
user_pref("gfx.font_rendering.cleartype_params.force_gdi_classic_max_size", 6);
user_pref("gfx.font_rendering.cleartype_params.pixel_structure", 1);
user_pref("gfx.font_rendering.cleartype_params.rendering_mode", 5);
user_pref("gfx.font_rendering.directwrite.use_gdi_table_loading", false);
user_pref("userChromeJS.persistent_domcontent_callback", true);
////

//// recommended userChrome... prefs created by the theme or scripts. there are
//// many more not included here, to allow a lot more customization. these are
//// just the ones I'm pretty certain 90% of users will want. see the prefs list
//// at https://github.com/aminomancer/uc.css.js
user_pref("userChrome.tabs.pinned-tabs.close-buttons.disabled", true);
user_pref("userChrome.urlbar-results.hide-help-button", true);
// add a drop shadow on menupopup and panel elements (e.g. context menus)
user_pref("userChrome.css.menupopup-shadows", true);
//// these are more subjective prefs, but they're important ones
//// display the all tabs menu in reverse order (newer tabs on top, like history)
// user_pref("userChrome.tabs.all-tabs-menu.reverse-order", true);
// turn bookmarks on the toolbar into small square buttons with no text labels
// user_pref("userChrome.bookmarks-toolbar.icons-only", false);
// replace UI font with SF Pro, the system font for macOS.
// recommended for all operating systems, but not required.
// must have the fonts installed. check the repo's readme for more details.
// user_pref("userChrome.css.mac-ui-fonts", true);
// custom wikipedia dark mode theme
// user_pref("userChrome.css.wikipedia.dark-theme-enabled", true);

// natsumi browser
user_pref("natsumi.theme.disable-translucency", true);

pref("general.config.obscure_value", 0);
pref("general.config.filename", "config.js");
// Sandbox needs to be disabled in release and Beta versions
pref("general.config.sandbox_enabled", false);
pref("accessibility.force_disabled","1");
              '';
        };
    };
  };
}
