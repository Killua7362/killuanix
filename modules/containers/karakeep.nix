# Karakeep (formerly Hoarder) — self-hosted bookmark + read-later + AI tagging
# app, reachable at http://localhost:9090. Two-container stack:
#
#   - karakeep        — web UI + worker (Next.js), uses bundled SQLite at /data
#   - karakeep-meili  — Meilisearch instance for full-text search
#
# Both sit on the karakeep-net podman network (10.89.3.0/24 — declared in
# modules/containers/default.nix). The web container reaches meili via the
# container-name DNS `http://karakeep-meili:7700`.
#
# Two sops-driven secrets, staged into env files at boot:
#   karakeep-env.service        → /run/karakeep/env       (web container)
#   karakeep-meili-env.service  → /run/karakeep-meili/env (meili container)
#
# First-run user setup: open http://localhost:9090, sign up — the very first
# account becomes admin. There is no auto-admin-create env var like linkding's,
# so this is unavoidable. Subsequent signups can be disabled in admin settings.
#
# To enable AI auto-tagging: add `karakeep_openai_api_key` to sops + uncomment
# the OPENAI_API_KEY line in karakeep-env below.
{
  pkgs,
  config,
  ...
}: let
  sopsPath = name: config.sops.secrets.${name}.path;

  webImage = "ghcr.io/karakeep-app/karakeep:release";
  meiliImage = "docker.io/getmeili/meilisearch:v1.13.3";
in {
  virtualisation.quadlet.containers.karakeep-meili = {
    autoStart = false;

    containerConfig = {
      image = meiliImage;
      networks = ["karakeep-net"];
      # No publishPorts — only the web container talks to meili, and that goes
      # over the karakeep-net network. Keeps meili off the host loopback.
      volumes = [
        "karakeep_meili_data:/meili_data:z"
      ];
      environments = {
        MEILI_NO_ANALYTICS = "true";
        MEILI_ENV = "production";
      };
      environmentFiles = ["/run/karakeep-meili/env"];
      labels = ["io.containers.autoupdate=registry"];
    };

    serviceConfig = {
      Restart = "always";
      TimeoutStartSec = 300;
    };

    unitConfig = {
      Description = "Karakeep - Meilisearch (full-text search backend)";
      After = [
        "network-online.target"
        "podman.socket"
        "karakeep-meili-env.service"
      ];
      Requires = [
        "podman.socket"
        "karakeep-meili-env.service"
      ];
    };
  };

  virtualisation.quadlet.containers.karakeep = {
    autoStart = false;

    containerConfig = {
      image = webImage;
      networks = ["karakeep-net"];
      publishPorts = ["127.0.0.1:9090:3000"];
      volumes = [
        "karakeep_data:/data:z"
      ];
      environments = {
        DATA_DIR = "/data";
        NEXTAUTH_URL = "http://localhost:9090";
        MEILI_ADDR = "http://karakeep-meili:7700";
        DISABLE_NEW_RELEASE_CHECK = "true";
      };
      environmentFiles = ["/run/karakeep/env"];
      labels = ["io.containers.autoupdate=registry"];
    };

    serviceConfig = {
      Restart = "always";
      TimeoutStartSec = 300;
    };

    unitConfig = {
      Description = "Karakeep - bookmark + read-later app";
      After = [
        "network-online.target"
        "podman.socket"
        "karakeep-env.service"
        "karakeep-meili.service"
      ];
      Requires = [
        "podman.socket"
        "karakeep-env.service"
        "karakeep-meili.service"
      ];
    };
  };

  # Meilisearch master key — required even though we don't expose meili to the
  # host. Without it meilisearch refuses to start in production mode.
  systemd.services.karakeep-meili-env = {
    description = "Assemble Karakeep Meilisearch env file from sops secrets";
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      RuntimeDirectory = "karakeep-meili";
      RuntimeDirectoryMode = "0700";
    };
    script = ''
      umask 077
      {
        printf 'MEILI_MASTER_KEY=%s\n' "$(cat ${sopsPath "karakeep_meili_master_key"})"
      } > /run/karakeep-meili/env
    '';
  };

  # Sentinel directory for karakeep-bootstrap so we don't re-POST the admin
  # signup on every boot.
  systemd.tmpfiles.rules = [
    "d /var/lib/karakeep 0700 root root -"
  ];

  # First-boot admin seeder. Hits Karakeep's public signup endpoint with the
  # sops-stored email + password, idempotent via /var/lib/karakeep/.admin-seeded
  # marker. Re-runs only when that file is missing (i.e. fresh install /
  # `rm /var/lib/karakeep/.admin-seeded` + restart to force a re-attempt).
  #
  # NOTE: signups must still be enabled at the time this runs. If you disable
  # them in Admin Settings, this becomes a no-op on the next fresh volume —
  # remove the sentinel + re-enable signups temporarily before rebooting.
  systemd.services.karakeep-bootstrap = {
    description = "Seed Karakeep admin user from sops on first boot";
    wantedBy = ["multi-user.target"];
    after = ["karakeep.service"];
    requires = ["karakeep.service"];
    path = [pkgs.curl pkgs.coreutils pkgs.jq];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -u

      SENTINEL=/var/lib/karakeep/.admin-seeded
      if [ -f "$SENTINEL" ]; then
        echo "karakeep admin already seeded; skipping"
        exit 0
      fi

      EMAIL="$(cat ${sopsPath "karakeep_admin_email"})"
      PASSWORD="$(cat ${sopsPath "karakeep_admin_password"})"

      # Wait for the Next.js app to be ready. /api/health returns 200 once
      # migrations + boot are done.
      for i in $(seq 1 60); do
        if curl -sf -o /dev/null --max-time 2 http://localhost:9090/api/health; then
          break
        fi
        sleep 2
      done

      flat=$(jq -nc --arg name admin --arg email "$EMAIL" --arg password "$PASSWORD" \
                    '{name:$name, email:$email, password:$password, confirmPassword:$password}')
      trpc=$(jq -nc --arg name admin --arg email "$EMAIL" --arg password "$PASSWORD" \
                    '{json:{name:$name, email:$email, password:$password, confirmPassword:$password}}')

      try() {
        local path="$1" body="$2"
        echo "  POST http://localhost:9090$path"
        status=$(curl -s -o /tmp/karakeep-bootstrap.out -w '%{http_code}' \
            -H 'Content-Type: application/json' \
            -X POST "http://localhost:9090$path" \
            --data "$body" || true)
        body_snip="$(head -c 200 /tmp/karakeep-bootstrap.out 2>/dev/null)"
        case "$status" in
          200|201)
            echo "    OK ($status) via $path"
            touch "$SENTINEL"
            rm -f /tmp/karakeep-bootstrap.out
            exit 0
            ;;
          409)
            echo "    409 conflict — admin already exists; marking sentinel"
            touch "$SENTINEL"
            rm -f /tmp/karakeep-bootstrap.out
            exit 0
            ;;
          *)
            if echo "$body_snip" | grep -qiE 'exist|already|conflict'; then
              echo "    $status — admin already exists; marking sentinel"
              touch "$SENTINEL"
              rm -f /tmp/karakeep-bootstrap.out
              exit 0
            fi
            echo "    HTTP $status — $body_snip"
            ;;
        esac
      }

      # tRPC v10 signup routes Karakeep is known to expose under different names.
      try /api/trpc/users.create       "$trpc"
      try /api/trpc/users.signup       "$trpc"
      try /api/trpc/users.signUp       "$trpc"
      try /api/trpc/auth.signUp        "$trpc"
      # Legacy / REST candidates.
      try /api/v1/users/signup         "$flat"
      try /api/users/signup            "$flat"
      try /api/auth/signup             "$flat"

      echo
      echo "karakeep-bootstrap: no signup endpoint matched. Falling through to" >&2
      echo "  manual signup. Marking sentinel so this service is a no-op" >&2
      echo "  next boot — your first UI signup becomes admin." >&2
      touch "$SENTINEL"
      rm -f /tmp/karakeep-bootstrap.out
      # Exit 0 — nix_switch must not fail just because karakeep changed its
      # signup endpoint upstream.
      exit 0
    '';
  };

  # Import the sops-encrypted Netscape HTML bookmark export into Karakeep,
  # placing every imported URL into a single "Imported from sops" list. Runs
  # on boot AND on a daily timer so the list "always reflects" the encrypted
  # HTML — edit `secrets/karakeep-bookmarks.html` via sops, the next timer
  # tick (or `systemctl start karakeep-import`) picks the new set up.
  #
  # IDEMPOTENCY: Karakeep dedupes bookmarks by URL on POST, so re-running is
  # safe. NOTE: this importer is **additive only** — URLs removed from the
  # HTML are NOT deleted from Karakeep; remove them in the UI if needed.
  #
  # PREREQUISITE: karakeep_admin_api_key in sops must be set. Generate one
  # in the Karakeep UI (Settings → API Keys → Create) after first login,
  # then `sops secrets/personal.yaml` to add it. Before then this service
  # logs a hint and exits 0.
  systemd.services.karakeep-import = {
    description = "Import sops-encrypted Netscape HTML bookmarks into Karakeep";
    wantedBy = ["multi-user.target"];
    after = ["karakeep.service" "karakeep-bootstrap.service"];
    requires = ["karakeep.service"];
    path = [pkgs.curl pkgs.jq pkgs.coreutils pkgs.gnugrep pkgs.gnused];
    serviceConfig = {
      Type = "oneshot";
    };
    script = ''
      set -u

      BASE=http://localhost:9090
      API_KEY="$(cat ${sopsPath "karakeep_admin_api_key"})"
      HTML="${sopsPath "karakeep_bookmarks_html"}"

      if [ -z "$API_KEY" ] || [ "$API_KEY" = "PLACEHOLDER" ] || [ "$API_KEY" = "TODO" ]; then
        echo "karakeep_admin_api_key not populated in sops yet — skipping import"
        echo "  generate one in Karakeep Settings → API Keys, then sops it in."
        exit 0
      fi
      if [ ! -s "$HTML" ]; then
        echo "no bookmarks HTML to import (decrypted file empty/missing)"
        exit 0
      fi

      # Wait for karakeep web to be ready.
      for i in $(seq 1 60); do
        if curl -sf -o /dev/null --max-time 2 "$BASE/api/health"; then
          break
        fi
        sleep 2
      done

      AUTH="Authorization: Bearer $API_KEY"

      # Probe auth before doing any work. If the key in sops is stale/wrong
      # the API replies 401 — log + exit 0 so a missing rotation doesn't
      # fail the whole nixos-rebuild. Rotate via Karakeep UI → Settings →
      # API Keys, then `sops secrets/personal.yaml`.
      auth_code=$(curl -s -o /dev/null -w '%{http_code}' -H "$AUTH" "$BASE/api/v1/lists")
      if [ "$auth_code" = "401" ] || [ "$auth_code" = "403" ]; then
        echo "karakeep API rejected the key (HTTP $auth_code) — skipping import"
        echo "  regenerate karakeep_admin_api_key in the UI, then update sops."
        exit 0
      fi
      if [ "$auth_code" != "200" ]; then
        echo "unexpected HTTP $auth_code from /api/v1/lists — aborting"
        exit 1
      fi

      # Ensure the destination list exists.
      LIST_NAME="Imported from sops"
      LIST_ID=$(curl -sf -H "$AUTH" "$BASE/api/v1/lists" 2>/dev/null \
                | jq -r --arg n "$LIST_NAME" '.lists[]? | select(.name == $n) | .id' \
                | head -1)
      if [ -z "$LIST_ID" ]; then
        echo "creating list \"$LIST_NAME\""
        LIST_ID=$(curl -s -H "$AUTH" -H 'Content-Type: application/json' \
            -X POST "$BASE/api/v1/lists" \
            --data "$(jq -nc --arg n "$LIST_NAME" '{name:$n, icon:"📥"}')" \
            | jq -r '.id // empty')
      fi
      if [ -z "$LIST_ID" ]; then
        echo "could not get/create destination list — aborting (auth/api shape mismatch?)"
        exit 1
      fi
      echo "destination list id: $LIST_ID"

      # Parse Netscape HTML. Each bookmark line looks like:
      #   <DT><A HREF="https://..." ADD_DATE="..." ...>Title</A>
      # Extract URL + title in one pass with sed -n.
      total=0
      added=0
      while IFS=$'\t' read -r url title; do
        [ -z "$url" ] && continue
        total=$((total + 1))
        resp=$(curl -s -H "$AUTH" -H 'Content-Type: application/json' \
            -X POST "$BASE/api/v1/bookmarks" \
            --data "$(jq -nc --arg u "$url" --arg t "$title" '{type:"link", url:$u, title:$t}')")
        bm_id=$(echo "$resp" | jq -r '.id // empty')
        if [ -z "$bm_id" ]; then
          echo "  skip (no id from POST): $url — $(echo "$resp" | head -c 160)"
          continue
        fi
        # Attach to list (idempotent server-side).
        curl -s -o /dev/null -H "$AUTH" -H 'Content-Type: application/json' \
            -X PUT "$BASE/api/v1/lists/$LIST_ID/bookmarks/$bm_id" || true
        added=$((added + 1))
      done < <(
        sed -n -E 's@.*<A[^>]*HREF="([^"]+)"[^>]*>([^<]*)</A>.*@\1\t\2@p' "$HTML"
      )

      echo "import done: $added / $total bookmarks attached to \"$LIST_NAME\""
    '';
  };

  systemd.timers.karakeep-import = {
    description = "Daily re-sync of sops bookmarks into Karakeep";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      Unit = "karakeep-import.service";
    };
  };

  # Web container env: NEXTAUTH_SECRET for session signing + the same
  # MEILI_MASTER_KEY so the web container can authenticate to meili.
  systemd.services.karakeep-env = {
    description = "Assemble Karakeep web env file from sops secrets";
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      RuntimeDirectory = "karakeep";
      RuntimeDirectoryMode = "0700";
    };
    script = ''
      umask 077
      {
        printf 'NEXTAUTH_SECRET=%s\n' "$(cat ${sopsPath "karakeep_nextauth_secret"})"
        printf 'MEILI_MASTER_KEY=%s\n' "$(cat ${sopsPath "karakeep_meili_master_key"})"
        printf 'OPENAI_API_KEY=%s\n' "$(cat ${sopsPath "karakeep_openai_api_key"})"
      } > /run/karakeep/env
    '';
  };
}
