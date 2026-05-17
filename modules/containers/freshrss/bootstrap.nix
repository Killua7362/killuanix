# FreshRSS bootstrap — declarative per-user prefs + API-password re-apply.
#
# Why two services:
#   • freshrss-bootstrap-user-cfg.service
#       Hash-gated. Merges the nix-rendered per-user overrides into
#       data/users/<user>/config.php inside the running container. Re-runs
#       whenever the rendered file's hash changes, so flipping a value in nix
#       reliably propagates on the next nix_switch. Volatile / auth-bearing
#       fields (passwordHash, apiPasswordHash, feverKey, salt) are preserved
#       via array_replace_recursive — only the keys we declare get replaced.
#
#   • freshrss-bootstrap-api-pw.service
#       Runs every boot (no sentinel). Calls cli/update-user.php --api-password
#       so the Google Reader API credential is always whatever sops says. This
#       complements the install-time ADMIN_API_PASSWORD seed (which only fires
#       once, against an empty data volume).
#
# Toggle features by editing the `userConfig` attrset below. Commented entries
# are off; uncomment to enable. To activate an extension you must ALSO include
# it in extensions.nix (the binary has to be on-disk before FreshRSS will
# honor `extensions_enabled[<id>] = true`).
{
  pkgs,
  lib,
  config,
  ...
}: let
  user = "killua";

  # Anonymous-readable RSS token. Embedded into the FreshRSS user `token` field
  # so `/?a=rss&user=<user>&token=<this>` returns the user's aggregate feed
  # without password auth. Reused by the Glance dashboard widget. Localhost-only
  # access (FreshRSS is bound to 127.0.0.1), so the nix-store cleartext is
  # acceptable on a single-user box. Rotate by editing this value + nix_switch.
  rssToken = "glance-localhost-ro-7b3d9e1f4a2c6088";

  # ── DECLARATIVE PER-USER PREFS ──────────────────────────────────────────────
  # Keys match data/users/<user>/config.php in upstream FreshRSS. Full reference:
  #   https://github.com/FreshRSS/FreshRSS/blob/edge/config-user.default.php
  # Anything we don't set here keeps whatever the user (or upstream default)
  # has in the existing file.
  userConfig = {
    # Theme / look
    theme = "Origine-Compact"; # other built-ins: Origine, Mapco, Photonic, Pafat, Screwdriver, Aged, Alternative-Origine, Dark, Forest, Funky, Mapco, Mapco-Bigger, Origine-Compact, Origine-Mobile, Pure, Swage, Swage-Mobile, Tete-a-Tete, Topaz
    darkMode = "auto"; # auto | light | dark
    content_width = "thin"; # thin | medium | large | no_limit
    icons_as_emojis = false;
    show_favicons = true;

    # Reading flow
    posts_per_page = 50;
    default_view = "all"; # all | unread | favorites | adaptive
    view_mode = "normal"; # normal | global | reader
    auto_load_more = true;
    hide_read_feeds = true;
    sides_close_article = true;
    onread_jump_next = true;
    reading_confirm = false;
    sticky_post = false;
    lazyload = true;
    display_categories = "active"; # active | remember | all | none

    # Sorting
    sort = "date";
    sort_order = "DESC"; # ASC | DESC

    # Anonymous RSS token — see `rssToken` binding above for usage.
    token = rssToken;

    # Auto-mark-read triggers
    mark_when = {
      article = true;
      gone = false;
      reception = false;
      scroll = false;
      focus = false;
      site = true;
    };

    # Toplines (per-article header bar — booleans unless noted)
    topline_read = true;
    topline_favorite = true;
    topline_summary = true;
    topline_thumbnail = true;
    topline_date = true;
    topline_display_authors = true;
    topline_website = "full"; # full | short | none
    topline_link = true;
    # topline_sharing = true;     # show the sharing destinations bar

    # Notifications (HTML5 desktop notifs)
    html5_enable_notif = false;
    html5_notif_timeout = 0;

    # Archiving (per-feed defaults — overridable per-feed in UI)
    archiving = {
      keep_period = "P3M"; # ISO-8601 duration: P3M = 3 months
      keep_max = 200;
      keep_min = 50;
      keep_favourites = true;
      keep_unreads = true;
      keep_labels = true;
    };

    # Feed defaults
    ttl_default = 3600;
    since_hours_posts_per_rss = 168;
    max_posts_per_rss = 400;

    # Extensions: enable everything we ship via extensions.nix automatically.
    # The list is derived from `services.freshrssExtensions.enabledIds` so the
    # two files can't drift.
    extensions_enabled = builtins.listToAttrs (map (id: {
        name = id;
        value = true;
      })
      config.services.freshrssExtensions.enabledIds);

    # Per-extension config (only set when an extension exposes options).
    # Uncomment when you enable the matching extension:
    # extensions = {
    #   "xExtension-ReadingTime" = {
    #     wpm = 200;
    #   };
    #   "xExtension-YouTube" = {
    #     videoFormat = "iframe";       # iframe | div
    #     showVideoOnly = false;
    #   };
    # };

    # Sharing destinations — bar appears under each article when topline_sharing
    # is true. type ∈ shaarli | wallabag | diaspora | email | print | twitter |
    # mastodon | Known | link.
    # sharing = [
    #   { type = "shaarli";  name = "Shaarli";   url = "https://shaarli.example/";  method = "GET"; }
    #   { type = "wallabag"; name = "Wallabag";  url = "https://wallabag.example/"; method = "POST"; }
    #   { type = "mastodon"; name = "Mastodon";  url = "https://mastodon.social/";  method = "GET"; }
    # ];

    # Saved searches (appear in the sidebar as one-click filters)
    # queries = [
    #   { search = "intitle:rust"; state = 1; name = "Rust headlines"; }
    #   { search = "is:unread is:starred"; state = 1; name = "Starred unread"; }
    # ];
  };

  # ── Nix attrset → PHP array literal ─────────────────────────────────────────
  # Emits short-array `[ ... ]` syntax. Handles bool, int, float, string, list,
  # attrset. Used to render the overrides file applied via array_replace_recursive.
  phpEscape = s: lib.replaceStrings ["\\" "'"] ["\\\\" "\\'"] s;
  toPhp = v:
    if builtins.isBool v
    then
      (
        if v
        then "true"
        else "false"
      )
    else if builtins.isInt v || builtins.isFloat v
    then toString v
    else if builtins.isString v
    then "'${phpEscape v}'"
    else if builtins.isNull v
    then "null"
    else if builtins.isList v
    then "[${lib.concatStringsSep ", " (map toPhp v)}]"
    else if builtins.isAttrs v
    then "[${lib.concatStringsSep ", " (lib.mapAttrsToList (k: val: "'${phpEscape k}' => ${toPhp val}") v)}]"
    else throw "toPhp: unsupported type ${builtins.typeOf v}";

  overridesContents = ''
    <?php
    return ${toPhp userConfig};
  '';
  overridesPhp = pkgs.writeText "freshrss-user-overrides.php" overridesContents;

  # Hash bumps any time the rendered content changes → service re-runs the
  # merge. Using hashString avoids IFD: we compute the hash from the same
  # source string the writeText derivation uses, no need to read it back.
  overridesHash = builtins.hashString "sha256" overridesContents;
in {
  # Ensure the admin user exists. The upstream image's entrypoint only seeds
  # the `_` placeholder reliably; the conditional admin-create step has raced
  # the env-file in practice (volume seeded with no admin → bootstrap-user-cfg
  # then fails forever). Run create-user.php inside the container if the user
  # dir is missing, then promote to admin by setting `default_user` in the
  # global data/config.php (FreshRSS has no per-user is-admin flag — admin is
  # whichever username equals `default_user`). Idempotent: skips create when
  # the dir already exists; default_user write is unconditional but cheap.
  systemd.services.freshrss-bootstrap-create-user = {
    description = "Create FreshRSS admin user inside container if missing";
    wantedBy = ["multi-user.target"];
    after = ["freshrss.service" "freshrss-env.service"];
    requires = ["freshrss.service" "freshrss-env.service"];
    before = ["freshrss-bootstrap-user-cfg.service" "freshrss-bootstrap-api-pw.service"];
    path = [pkgs.podman pkgs.coreutils];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -eu

      # Wait until the container is up enough to exec into.
      for _ in $(seq 1 60); do
        if podman exec freshrss test -d /var/www/FreshRSS/data; then
          break
        fi
        sleep 2
      done

      # 1. If FreshRSS itself isn't installed (no global data/config.php), run
      #    do-install.php. The upstream image entrypoint normally does this on
      #    an empty volume but has raced the env-file in practice. Idempotent:
      #    skip when config.php already there.
      if ! podman exec freshrss test -f /var/www/FreshRSS/data/config.php; then
        echo "freshrss-bootstrap-create-user: running do-install.php"
        podman exec freshrss \
          su -s /bin/sh www-data -c 'php /var/www/FreshRSS/cli/do-install.php \
            --default-user ${user} \
            --auth-type form \
            --language en \
            --db-type sqlite'
      fi

      # 2. Create the admin user if missing. do-install registers `--default-user`
      #    as the admin name in config.php but does NOT create the user record —
      #    create-user.php does that.
      if ! podman exec freshrss test -f /var/www/FreshRSS/data/users/${user}/config.php; then
        echo "freshrss-bootstrap-create-user: creating ${user}"
        podman exec --env-file /run/freshrss/env freshrss \
          su -s /bin/sh www-data -c 'php /var/www/FreshRSS/cli/create-user.php \
            --user ${user} \
            --password "$ADMIN_PASSWORD" \
            --api-password "$ADMIN_API_PASSWORD" \
            --email akshay@altdigital.tech \
            --language en'
      else
        echo "freshrss-bootstrap-create-user: ${user} already present"
      fi

      # 3. Ensure default_user = ${user} AND api_enabled = true in global
      #    data/config.php. FreshRSS has no per-user is-admin flag — admin is
      #    whoever matches default_user. api_enabled is the global gate for
      #    the Google Reader / Fever endpoints (without it FreshRSS returns
      #    503 even when the user has an apiPasswordHash).
      podman exec freshrss su -s /bin/sh www-data -c "php -r '\$p=\"/var/www/FreshRSS/data/config.php\"; \$c=require(\$p); \$changed=false; if ((\$c[\"default_user\"] ?? null) !== \"${user}\") { \$c[\"default_user\"]=\"${user}\"; echo \"default_user → ${user}\\n\"; \$changed=true; } if ((\$c[\"api_enabled\"] ?? null) !== true) { \$c[\"api_enabled\"]=true; echo \"api_enabled → true\\n\"; \$changed=true; } if (\$changed) { file_put_contents(\$p, \"<?php\\nreturn \".var_export(\$c,true).\";\\n\"); } else { echo \"global config already correct\\n\"; }'"
    '';
  };

  systemd.services.freshrss-bootstrap-user-cfg = {
    description = "Merge nix-declared FreshRSS per-user prefs into config.php";
    wantedBy = ["multi-user.target"];
    after = ["freshrss.service" "freshrss-bootstrap-create-user.service"];
    requires = ["freshrss.service" "freshrss-bootstrap-create-user.service"];
    path = [pkgs.podman pkgs.coreutils];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -eu

      SENTINEL=/var/lib/freshrss/state/.user-cfg-applied
      WANTED="${overridesHash}"
      if [ -f "$SENTINEL" ] && [ "$(cat "$SENTINEL")" = "$WANTED" ]; then
        echo "freshrss-bootstrap-user-cfg: hash $WANTED already applied"
        exit 0
      fi

      # Wait until FreshRSS is reachable (the entrypoint installs the data dir
      # on first boot; we must run after that).
      for _ in $(seq 1 60); do
        if podman exec freshrss test -f /var/www/FreshRSS/data/users/${user}/config.php; then
          break
        fi
        sleep 2
      done

      if ! podman exec freshrss test -f /var/www/FreshRSS/data/users/${user}/config.php; then
        echo "freshrss-bootstrap-user-cfg: per-user config.php missing — entrypoint hasn't seeded yet, retry later" >&2
        exit 1
      fi

      # Ship overrides file in, deep-merge, write back. array_replace_recursive
      # preserves passwordHash/apiPasswordHash/feverKey/salt that we don't set.
      podman cp ${overridesPhp} freshrss:/tmp/overrides.php
      podman exec freshrss php -r '
        $path = "/var/www/FreshRSS/data/users/${user}/config.php";
        $existing = require($path);
        $overrides = require("/tmp/overrides.php");
        $merged = array_replace_recursive($existing, $overrides);
        $out = "<?php\nreturn " . var_export($merged, true) . ";\n";
        file_put_contents($path, $out);
      '
      podman exec freshrss rm -f /tmp/overrides.php

      echo "$WANTED" > "$SENTINEL"
      echo "freshrss-bootstrap-user-cfg: applied overrides ($WANTED)"
    '';
  };

  # Re-apply the sops API password on every rebuild. The install-time
  # ADMIN_API_PASSWORD only fires against an empty data volume; this catches
  # the rotate-the-secret case without wiping the volume.
  systemd.services.freshrss-bootstrap-api-pw = {
    description = "Re-apply FreshRSS API password from sops via cli/update-user.php";
    wantedBy = ["multi-user.target"];
    after = ["freshrss.service" "freshrss-env.service" "freshrss-bootstrap-create-user.service"];
    requires = ["freshrss.service" "freshrss-bootstrap-create-user.service"];
    path = [pkgs.podman pkgs.coreutils];
    serviceConfig = {
      Type = "oneshot";
    };
    script = ''
      set -eu

      # Wait until the user exists inside the container.
      for _ in $(seq 1 60); do
        if podman exec freshrss test -f /var/www/FreshRSS/data/users/${user}/config.php; then
          break
        fi
        sleep 2
      done

      if ! podman exec freshrss test -f /var/www/FreshRSS/data/users/${user}/config.php; then
        echo "freshrss-bootstrap-api-pw: user ${user} not present yet — exiting 0 (will retry next boot)" >&2
        exit 0
      fi

      # The env file already contains ADMIN_API_PASSWORD; pass it through to
      # cli/update-user.php. Run as the apache user so file perms stay sane.
      podman exec --env-file /run/freshrss/env freshrss \
        su -s /bin/sh www-data -c 'php /var/www/FreshRSS/cli/update-user.php --user ${user} --api-password "$ADMIN_API_PASSWORD"'
    '';
  };
}
