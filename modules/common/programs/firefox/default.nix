{
  pkgs,
  lib,
  config,
  inputs,
  self,
  ...
}: let
  Firefox-custom = pkgs.wrapFirefox pkgs.firefox-unwrapped_nightly {};
in {
  imports = [
    inputs.arkenfox.hmModules.default
  ];

  home.sessionVariables.DEFAULT_BROWSER = "${Firefox-custom}/bin/firefox";

  programs.firefox = {
    enable = true;
    arkenfox = {
      enable = true;
      version = "140.0";
    };
    package = Firefox-custom;
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
    };

    profiles = {
      betterfox =
        {
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

              '';
        };
    };
  };
}
