# OPML feed-list import — drop-folder synced via Notes/.
#
# Drop any `*.opml` or `*.xml` file into `${cfg.inboxDir}` and `freshrss-import`
# imports it into FreshRSS:
#   • systemd.path watches the dir and fires the import service on file change.
#   • OnBootSec=2min + daily timer cover events that fire while the service is
#     inhibited (boot races, podman restart, etc.).
#
# Sync: cfg.inboxDir lives inside `~/killuanix/Notes/` so obsidian-git carries
# OPML files between hosts (chrollo + killua). Each host independently
# imports into its own local FreshRSS instance; sentinels are per-host so they
# don't conflict over the synced files.
#
# Idempotence via content-hash sentinels under `/var/lib/freshrss/state/`. The
# importer (cli/import-for-user.php) is already idempotent at the feed +
# entry level (dedupes by URL + GUID, confirmed against upstream), so the
# sentinels are purely a performance optimization to skip a no-op podman exec.
# Edit a file in place → its hash changes → import re-runs.
#
# Import is **additive only** — removing a feed from a file does NOT remove it
# from FreshRSS. Unsubscribe in the UI if you want feeds gone.
#
# Optional sops fallback: set `cfg.useSops = true` to also consume a curated
# OPML kept encrypted as the `freshrss_opml` secret.
{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = {
    enable = true;
    user = "killua";
    # Inbox dir — inside Notes/ so it syncs across hosts via obsidian-git.
    inboxDir = "/home/killua/killuanix/Notes/freshrss-opml";
    inboxOwner = "killua";
    inboxGroup = "users";
    useSops = false; # ← flip to true to also import from sops `freshrss_opml`
  };

  sopsPath = name: config.sops.secrets.${name}.path;
in
  lib.mkIf cfg.enable {
    sops.secrets = lib.mkIf cfg.useSops {
      freshrss_opml = {};
    };

    # Create the inbox dir if missing (z = chown-if-exists too, in case the
    # user mkdir'd it manually first). Mode 0775 so killua can drop files
    # without sudo.
    systemd.tmpfiles.rules = [
      "d ${cfg.inboxDir} 0775 ${cfg.inboxOwner} ${cfg.inboxGroup} - -"
    ];

    systemd.services.freshrss-import = {
      description = "Import OPML files from Notes inbox into FreshRSS";
      after = ["freshrss.service" "freshrss-bootstrap-user-cfg.service"];
      requires = ["freshrss.service"];
      path = [pkgs.podman pkgs.coreutils pkgs.findutils pkgs.gnused];
      serviceConfig = {
        Type = "oneshot";
        RuntimeDirectory = "freshrss-import";
        RuntimeDirectoryMode = "0700";
      };
      script = ''
        set -eu

        STATE=/var/lib/freshrss/state

        # Wait until FreshRSS has provisioned the user dir.
        for _ in $(seq 1 60); do
          if podman exec freshrss test -d /var/www/FreshRSS/data/users/${cfg.user}; then
            break
          fi
          sleep 2
        done

        import_one() {
          local src="$1"
          local label="$2"
          local hash
          hash=$(sha256sum "$src" | cut -d' ' -f1)
          local sentinel="$STATE/opml-$hash.imported"

          if [ -f "$sentinel" ]; then
            echo "freshrss-import: skip $label (hash $hash already imported)"
            return 0
          fi

          echo "freshrss-import: importing $label (hash $hash)"
          cp "$src" /run/freshrss-import/feed.opml

          # FreshRSS's OPML importer stores xmlUrl attribute values verbatim,
          # without decoding XML entities. URLs that legitimately contain `&`
          # (e.g. rss-bridge `?action=display&bridge=...&format=Atom`) must be
          # written as `&amp;` in the OPML to keep the file valid XML, but
          # they then get stored with the literal `&amp;` and the feed fetcher
          # hits a broken URL. Pre-decode `&amp;` inside xmlUrl="..." values
          # (greedy capture + loop = idempotent convergence).
          while grep -qE 'xmlUrl="[^"]*&amp;' /run/freshrss-import/feed.opml; do
            sed -i -E 's|(xmlUrl="[^"]*)&amp;|\1\&|' /run/freshrss-import/feed.opml
          done

          podman cp /run/freshrss-import/feed.opml freshrss:/tmp/feed.opml
          podman exec freshrss su -s /bin/sh www-data -c \
            'php /var/www/FreshRSS/cli/import-for-user.php --user ${cfg.user} --filename /tmp/feed.opml'
          podman exec freshrss rm -f /tmp/feed.opml
          rm -f /run/freshrss-import/feed.opml
          touch "$sentinel"
        }

        # 1. Drop-folder. Any *.opml or *.xml (case-insensitive). No rename —
        #    sentinels handle dedupe so the Notes folder stays clean.
        if [ -d ${cfg.inboxDir} ]; then
          find ${cfg.inboxDir} -maxdepth 1 -type f \
            \( -iname '*.opml' -o -iname '*.xml' \) \
            -print0 \
          | while IFS= read -r -d "" f; do
            import_one "$f" "$(basename "$f")"
          done
        fi

        ${lib.optionalString cfg.useSops ''
          SOPS_OPML="${sopsPath "freshrss_opml"}"
          if [ -s "$SOPS_OPML" ]; then
            import_one "$SOPS_OPML" "sops:freshrss_opml"
          fi
        ''}

        echo "freshrss-import: done"
      '';
    };

    # Path watcher — any file change in the inbox dir fires the import service.
    # PathModified matches mtime changes on the dir itself or its direct
    # children, so dropping a new file or editing an existing one both trigger.
    systemd.paths.freshrss-import = {
      description = "Watch Notes OPML inbox for new files";
      wantedBy = ["multi-user.target"];
      pathConfig = {
        PathModified = cfg.inboxDir;
        Unit = "freshrss-import.service";
      };
    };

    # Catch-all: import-on-boot (after 2 min so freshrss has time to come up)
    # and daily resync.
    systemd.timers.freshrss-import = {
      description = "Boot + daily OPML resync (catch-all)";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "2min";
        OnCalendar = "daily";
        Persistent = true;
        Unit = "freshrss-import.service";
      };
    };
  }
