{
  pkgs,
  lib,
  ...
}: let
  buildXpi = pkgs.nur.repos.rycee.firefox-addons.buildFirefoxXpiAddon;

  tbAddons = {
    thunderbird-conversations = buildXpi {
      pname = "thunderbird-conversations";
      version = "4.3.9";
      addonId = "gconversation@xulforum.org";
      url = "https://addons.thunderbird.net/thunderbird/downloads/file/1045419/thunderbird_conversations-4.3.9-tb.xpi";
      sha256 = "0ajw8p2z7vhhfb419i4kklzynrx23faf3lzw5y0hcrizfirxrljm";
      meta = {};
    };

    filtaquilla = buildXpi {
      pname = "filtaquilla";
      version = "6.1";
      addonId = "filtaquilla@mesquilla.com";
      url = "https://addons.thunderbird.net/thunderbird/downloads/file/1044060/filtaquilla-6.1-tb.xpi";
      sha256 = "1xskqv7w2alhrjyyhd11rxpzffa9vplwm849ch4fiin75r1fdyd4";
      meta = {};
    };

    quicktext = buildXpi {
      pname = "quicktext";
      version = "6.4";
      addonId = "{8845E3B3-E8FB-40E2-95E9-EC40294818C4}";
      url = "https://addons.thunderbird.net/thunderbird/downloads/file/1040393/quicktext-6.4-tb.xpi";
      sha256 = "0lnppqij2sf7vr8wn3wc6x3c6b0k0a2zq9f9fh65wvv9f7lr2zgb";
      meta = {};
    };

    mailmindr = buildXpi {
      pname = "mailmindr";
      version = "1.7.1";
      addonId = "mailmindr@arndissler.net";
      url = "https://addons.thunderbird.net/thunderbird/downloads/file/1031426/mailmindr-1.7.1-tb.xpi";
      sha256 = "16660j77d3pqlv8bi845b5fsnga8v781rd5dkx95j0iq27g6qwyr";
      meta = {};
    };

    send-later = buildXpi {
      pname = "send-later";
      version = "10.7.8";
      addonId = "sendlater3@kamens.us";
      url = "https://addons.thunderbird.net/thunderbird/downloads/file/1042516/send_later-10.7.8-tb.xpi";
      sha256 = "1w03qm7yid075hbgz9mv97vhvgaxhdi2mlarrpck2952r2xhwaf6";
      meta = {};
    };

    minimizetotray-reanimated = buildXpi {
      pname = "minimizetotray-reanimated";
      version = "1.4.11";
      addonId = "mintray-reanimated@ysard";
      url = "https://addons.thunderbird.net/thunderbird/downloads/file/1012680/minimizetotray_reanimated-1.4.11-sm+tb.xpi";
      sha256 = "159fsvsv58n6p1sl9vh2xas93qxaqpllq35psm4ca9nh8w7djs2c";
      meta = {};
    };

    removedupes = buildXpi {
      pname = "removedupes";
      version = "0.6.4";
      addonId = "{a300a000-5e21-4ee0-a115-9ec8f4eaa92b}";
      url = "https://addons.thunderbird.net/thunderbird/downloads/file/1042514/remove_duplicate_messages-0.6.4-tb.xpi";
      sha256 = "0j033bahkkr6fv2kbsafjrjvj5qqypbgsfibfmm7lysjpb1j4grm";
      meta = {};
    };

    header-tools-lite = buildXpi {
      pname = "header-tools-lite";
      version = "2.4.7";
      addonId = "headerToolsLite@kaosmos.nnp";
      url = "https://addons.thunderbird.net/thunderbird/downloads/file/1044067/header_tools_lite-2.4.7-tb.xpi";
      sha256 = "10ksr7xwn9cr9lfcf48zzix0rr3w6dh7idgk9dhn8xhgdz2mvlsh";
      meta = {};
    };
  };
in {
  programs.thunderbird = {
    enable = lib.mkDefault (pkgs.stdenv.isLinux || pkgs.stdenv.isDarwin);

    profiles.default = {
      isDefault = true;

      extensions = builtins.attrValues tbAddons;

      settings = {
        "extensions.autoDisableScopes" = 0;
        "mail.pane_config.dynamic" = 2;
        "mailnews.default_sort_order" = 2;
        "mail.biff.alert.show_preview" = false;
        "privacy.donottrackheader.enabled" = true;
        "mail.compose.default_to_paragraph" = true;
        "mailnews.start_page.enabled" = false;
        "app.update.auto" = false;
      };
    };
  };
}
