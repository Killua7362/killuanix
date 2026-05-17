# Optional: seed the FreshRSS account row directly into RSSGuard's SQLite DB
# so the first launch shows the account without manual setup.
#
# Off by default. Flip `cfg.enable = true` to use. Two modes:
#
#   • mode = "schema-only" (recommended)
#       INSERT the Account row with password = "". On first launch RSSGuard
#       prompts once for the API password and stores its own ciphertext.
#       Zero secret material on disk under nix.
#
#   • mode = "with-password" (NOT YET IMPLEMENTED)
#       Would require a small SimpleCrypt helper that uses
#       ~/.config/rssguard4/config/key.private to encrypt the FreshRSS API
#       password before INSERT. The key is generated on first RSSGuard launch
#       and is not predictable, so we'd need a tiny C++ helper (vendored
#       simplecrypt.cc + buildCxx) executed by this service at activation
#       time. Documented here; not built yet because the schema-only path
#       solves 95% of the convenience with 0% of the cipher-key fragility.
#
# When `cfg.enable = true`, a systemd-user oneshot runs once per host (gated
# by a sentinel under $XDG_STATE_HOME) that:
#   1. Ensures RSSGuard's SQLite DB exists by running `rssguard --help` once
#      (which initializes ~/.config/rssguard4/database/database.db without
#      starting the GUI).
#   2. INSERTs the FreshRSS Account row if it isn't there.
#   3. Touches the sentinel so subsequent rebuilds are no-ops.
{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = {
    enable = true; # ← flip to true to seed FreshRSS account on first launch
    mode = "schema-only"; # "schema-only" | "with-password" (not implemented)
    url = "http://localhost:8083/api/greader.php/";
    username = "killua";
    service = 1; # 1=FreshRSS, 2=TheOldReader, 4=Bazqux, 8=Reedah, 16=Inoreader, 32=Miniflux, 1024=Other
    batchSize = 100;
    downloadOnlyUnread = false;
    intelligentSync = true;
    # Greader API parameter — RSSGuard skips fetching anything older than this
    # cutoff to keep the first sync cheap. RSSGuard's own UI defaults to
    # "today minus one year" the moment you tick "Intelligent synchronization".
    fetchNewerThan = "2025-05-17";
    showNodeUnread = false;
    showNodeImportant = false;
    showNodeLabels = false;
    showNodeProbes = false;
  };

  # Field shape mirrors what RSSGuard writes when you add a Greader account by
  # hand (dumped from Accounts.custom_data on 4.8.6). Missing keys make the
  # account properties dialog render empty fields. Order doesn't matter — JSON
  # but match upstream defaults for forward compat.
  customData = builtins.toJSON {
    batch_size = cfg.batchSize;
    download_only_unread = cfg.downloadOnlyUnread;
    fetch_newer_than = cfg.fetchNewerThan;
    intelligent_synchronization = cfg.intelligentSync;
    password = ""; # schema-only: user pastes on first launch (SimpleCrypt-encrypted thereafter)
    service = cfg.service;
    show_node_important = cfg.showNodeImportant;
    show_node_labels = cfg.showNodeLabels;
    show_node_probes = cfg.showNodeProbes;
    show_node_unread = cfg.showNodeUnread;
    url = cfg.url;
    username = cfg.username;
  };

  # Shell-escape via single-quoting + close-reopen for embedded apostrophes.
  shEscape = s: "'" + lib.replaceStrings ["'"] ["'\\''"] s + "'";
in
  lib.mkIf (pkgs.stdenv.isLinux && cfg.enable) {
    assertions = [
      {
        assertion = cfg.mode == "schema-only";
        message = "rss.account-seed: only mode=\"schema-only\" is implemented; with-password requires a SimpleCrypt helper that isn't built yet";
      }
    ];

    # Path unit fires the seed service the moment RSSGuard creates its DB.
    # RSSGuard 4.8.6's `--version` exits before Application::userDataHomeFolder()
    # runs, so we cannot pre-create the DB from a oneshot — instead we wait
    # for the user's first real launch.
    systemd.user.paths.rssguard-account-seed = {
      Unit = {
        Description = "Watch for RSSGuard DB to seed FreshRSS account";
      };
      Path = {
        PathExists = "%h/.config/RSS Guard 4/database/database.db";
        Unit = "rssguard-account-seed.service";
      };
      Install.WantedBy = ["default.target"];
    };

    systemd.user.services.rssguard-account-seed = {
      Unit = {
        Description = "Seed FreshRSS account row into RSSGuard's SQLite DB";
      };
      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = let
          script = pkgs.writeShellScript "rssguard-account-seed" ''
            set -eu
            STATE_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/rssguard4"
            mkdir -p "$STATE_DIR"
            SENTINEL="$STATE_DIR/.account-seeded"
            if [ -f "$SENTINEL" ]; then
              exit 0
            fi

            DB="''${XDG_CONFIG_HOME:-$HOME/.config}/RSS Guard 4/database/database.db"
            if [ ! -f "$DB" ]; then
              echo "rssguard-account-seed: $DB not present — path unit will retrigger when RSSGuard creates it" >&2
              exit 0
            fi

            # Bail if an Accounts row already exists for this URL — never clobber
            # whatever RSSGuard wrote.
            existing=$(${pkgs.sqlite}/bin/sqlite3 "$DB" \
              "SELECT COUNT(*) FROM Accounts WHERE type='greader' AND custom_data LIKE '%${cfg.url}%';" 2>/dev/null || echo 0)
            if [ "$existing" != "0" ]; then
              touch "$SENTINEL"
              exit 0
            fi

            ${pkgs.sqlite}/bin/sqlite3 "$DB" \
              "INSERT INTO Accounts (ordr, type, proxy_type, custom_data) VALUES (1, 'greader', 0, ${shEscape customData});"
            touch "$SENTINEL"
            echo "rssguard-account-seed: inserted greader account (${cfg.username}@${cfg.url})"
          '';
        in "${script}";
      };
    };
  }
