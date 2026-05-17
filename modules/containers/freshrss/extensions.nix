# FreshRSS extensions bundle.
#
# Builds a nix-store directory of selected FreshRSS extensions and exposes the
# path via `config.services.freshrssExtensions.bundle`, which default.nix bind-
# mounts at /var/www/FreshRSS/extensions/nix (THIRDPARTY_EXTENSIONS_PATH).
#
# Activation is per-user — even with the extension on-disk, FreshRSS won't run
# it until `extensions_enabled[<id>] = true` lands in
# data/users/<user>/config.php. That part is handled by bootstrap.nix; the
# enabled list there is derived from `services.freshrssExtensions.enabledIds`
# below so the two files can't drift.
#
# Each entry is `{ id, pkg }`:
#   • id  — exact on-disk directory name (e.g. "xExtension-YouTube"). This is
#           the same string that goes into `extensions_enabled` in the
#           per-user config.
#   • pkg — derivation that puts its files at $out/share/freshrss/extensions/<id>/.
#
# Adding an extension:
#   1. Uncomment / add the entry below (nixpkgs-curated or via buildFreshRssExtension).
#   2. `scripts/nix_switch` — bundle rebuilds, bootstrap pre-ticks the new
#      extension on the next run, container restarts cleanly.
#
# Removing an extension is the inverse — drop the entry, switch.
{
  pkgs,
  lib,
  config,
  ...
}: let
  ext = pkgs.freshrss-extensions;

  enabledExtensions = [
    {
      id = "xExtension-YouTube";
      pkg = ext.youtube;
    } # inline YouTube videos in the article view
    {
      id = "xExtension-ReadingTime";
      pkg = ext.reading-time;
    } # show estimated reading time per article
    # { id = "xExtension-RedditImage"; pkg = ext.reddit-image; } # inline images from Reddit feeds
    # { id = "xExtension-TitleWrap";   pkg = ext.title-wrap;   } # wrap long titles in list view
    # { id = "xExtension-AutoTTL";     pkg = ext.auto-ttl;     } # adapt feed TTL to publish frequency
    # { id = "xExtension-UnsafeAutoLogin"; pkg = ext.unsafe-auto-login; } # query-string auto-login (PRIVATE LAN ONLY)
    #
    # Community extensions not in nixpkgs — build via buildFreshRssExtension.
    # Make sure `id` matches the directory name inside the upstream tarball
    # (look for `metadata.json` next to it). nixpkgs's buildFreshRssExtension
    # places output at $out/share/freshrss/extensions/<pname>/, so set the
    # `pname` equal to the upstream id (e.g. pname = "xExtension-AutoRefresh").
    #
    # {
    #   id = "xExtension-AutoRefresh";
    #   pkg = ext.buildFreshRssExtension {
    #     pname = "xExtension-AutoRefresh";
    #     version = "unstable-2024-01-01";
    #     src = pkgs.fetchFromGitHub {
    #       owner = "Eisa01";
    #       repo = "FreshRSS---Auto-Refresh-Extension";
    #       rev = "main";
    #       hash = "sha256-AAAA...";
    #     };
    #   };
    # }
    # {
    #   id = "xExtension-FreshVibesView";
    #   pkg = ext.buildFreshRssExtension {
    #     pname = "xExtension-FreshVibesView";
    #     version = "unstable-2024-01-01";
    #     src = pkgs.fetchFromGitHub {
    #       owner = "tryallthethings";
    #       repo = "freshvibes";
    #       rev = "main";
    #       hash = "sha256-AAAA...";
    #     };
    #   };
    # }
  ];

  # Flatten $out/share/freshrss/extensions/<id>/ across all enabled extensions
  # into a single top-level dir that mirrors FreshRSS's layout (extensions/<id>/).
  bundle = pkgs.runCommand "freshrss-extensions-bundle" {} ''
    mkdir -p $out
    ${lib.concatMapStringsSep "\n" (e: ''
        if [ -d ${e.pkg}/share/freshrss/extensions/${e.id} ]; then
          ln -s ${e.pkg}/share/freshrss/extensions/${e.id} $out/${e.id}
        else
          echo "extensions.nix: ${e.id} not at \$out/share/freshrss/extensions — adjust path" >&2
          exit 1
        fi
      '')
      enabledExtensions}
  '';
in {
  options.services.freshrssExtensions = {
    bundle = lib.mkOption {
      type = lib.types.package;
      internal = true;
      description = "Joined nix-store directory of all enabled FreshRSS extensions.";
    };
    enabledIds = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      internal = true;
      description = "Extension ids (xExtension-<Name>) to activate in the per-user config.";
    };
  };

  config = {
    services.freshrssExtensions.bundle = bundle;
    services.freshrssExtensions.enabledIds = map (e: e.id) enabledExtensions;
  };
}
