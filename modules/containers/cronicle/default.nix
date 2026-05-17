# Cronicle — declarative cron with web UI, reachable at http://localhost:3012.
#
# Web UI controls: "Active" toggle (pause/resume), "Run Now", live log on the
# Job Details tab + history on Completed Jobs, Abort on running jobs.
#
# Default credentials on first boot are admin/admin — change via the UI on
# first login. The bootstrap pipeline does NOT use the admin password; it
# uses a long-lived api_key seeded once into the data volume by
# cronicle-init.service. So rotating the admin password in the UI is safe
# and does not break event sync.
#
# ── Adding events ──
#   Drop a `.nix` file under ./events/. Each file evaluates to an attrset:
#
#     {
#       enabled = true;            # nix-level on/off; false = present but greyed out
#       id = "my_event";           # stable id, used as the Cronicle event id
#       title = "Pretty title";
#       script = '' ... '';        # shell body run inside the container
#       timing = { hours = [3]; minutes = [30]; };
#       timezone = "Asia/Kolkata"; # optional
#       bindMounts = [             # optional host paths the script reads/writes
#         "/host/path:/container/path:rw"
#       ];
#       category = "general";      # optional; "general" is the built-in default
#       plugin   = "shellplug";    # optional; "shellplug" is the built-in shell runner
#       target   = "allgrp";       # optional; "allgrp" is the built-in target group
#       timeout  = 600;            # optional, seconds
#       notes    = "...";          # optional
#     }
#
# ── State machine ──
#   Disabled events are NOT removed from Cronicle — they're created with the
#   `enabled: 0` field, so they show up in the schedule list with the
#   "Active" checkbox off (greyed-out / not firing). This keeps history,
#   notes, and the event itself visible in the UI for easy re-enabling.
#
#   cronicle-bootstrap.service runs on every activation. For each event it
#   compares the per-event state at /var/lib/cronicle/state/<id> to the
#   desired state derived from `enabled`:
#
#     desired=active    + state missing/"inactive"     -> upsert with enabled=1, state:=active
#     desired=active    + state="active"               -> no-op (UI tweaks preserved)
#     desired=inactive  + state missing/"active"       -> upsert with enabled=0, state:=inactive
#     desired=inactive  + state="inactive"             -> no-op
#
#   So toggling `enabled` in nix is what flips the Active checkbox; pausing
#   the event from the UI on an active-in-nix event is sticky across rebuilds
#   because we don't re-touch when the sentinel matches the desired state.
#
#   Sync goes through Cronicle's REST API (update_event with a create_event
#   fallback). Earlier revisions of this module used `storage-cli.js` via
#   `podman exec`, which refuses while Cronicle is running ("Please stop
#   Cronicle before running this script.") — that's why the rewrite happened.
{pkgs, ...}: let
  inherit (builtins) attrNames filter map readDir toJSON;
  inherit (pkgs.lib) hasSuffix concatMap unique optionalAttrs concatStringsSep;

  eventsDir = ./events;

  eventFiles = filter (n: hasSuffix ".nix" n) (attrNames (readDir eventsDir));

  loaded = map (f: import (eventsDir + "/${f}")) eventFiles;

  enabledForMounts = filter (e: e.enabled or true) loaded;
  allBindMounts = unique (concatMap (e: e.bindMounts or []) enabledForMounts);

  cronicleImage = "docker.io/soulteary/cronicle:0.9.80";

  toEventAttrs = e:
    {
      id = e.id;
      title = e.title;
      category = e.category or "general";
      plugin = e.plugin or "shellplug";
      target = e.target or "allgrp";
      enabled =
        if (e.enabled or true)
        then 1
        else 0;
      timing = e.timing;
      timezone = e.timezone or "Asia/Kolkata";
      params = {
        script = e.script;
        annotate = 0;
        json = 0;
      };
      max_children = e.max_children or 1;
      timeout = e.timeout or 600;
      catch_up = e.catch_up or 0;
      queue = e.queue or 0;
      log_max_size = e.log_max_size or 10485760;
    }
    // optionalAttrs (e ? notes) {notes = e.notes;};

  eventPayloads =
    map (e: {
      inherit (e) id;
      desired =
        if (e.enabled or true)
        then "active"
        else "inactive";
      json = toJSON (toEventAttrs e);
    })
    loaded;

  # Single-quote-safe escape for embedding the JSON inside a bash
  # `printf '%s' '...'` line.
  shEscape = s: builtins.replaceStrings ["'"] ["'\\''"] s;

  mkSyncCmd = p: ''
    echo "[bootstrap] event ${p.id}: desired=${p.desired}"
    state="$(cat /var/lib/cronicle/state/${p.id} 2>/dev/null || true)"
    if [ "$state" = "${p.desired}" ]; then
      echo "[bootstrap] event ${p.id}: already in desired state, leaving Cronicle alone"
    else
      echo "[bootstrap] event ${p.id}: syncing (was '$state')"
      body="$(printf '%s' '${shEscape p.json}' | jq -c --arg s "$SESSION_ID" '. + {session_id:$s}')"

      # Try update first; if the event doesn't exist yet, fall back to create.
      resp="$(curl -sS -m 10 -X POST \
        -H 'Content-Type: application/json' \
        --data-binary "$body" \
        http://127.0.0.1:3012/api/app/update_event/v1)"
      code="$(printf '%s' "$resp" | jq -r '.code // 0')"
      if [ "$code" != "0" ]; then
        echo "[bootstrap] event ${p.id}: update returned code=$code, attempting create"
        resp="$(curl -sS -m 10 -X POST \
          -H 'Content-Type: application/json' \
          --data-binary "$body" \
          http://127.0.0.1:3012/api/app/create_event/v1)"
        code="$(printf '%s' "$resp" | jq -r '.code // 0')"
        if [ "$code" != "0" ]; then
          echo "[bootstrap] event ${p.id}: create FAILED: $resp"
          exit 1
        fi
      fi
      printf '%s' "${p.desired}" > /var/lib/cronicle/state/${p.id}
    fi
  '';
in {
  systemd.tmpfiles.rules = [
    "d /home/killua/.cache/claude-kit 0755 killua users -"
    "d /home/killua/.cache/claude-kit/sessions 0755 killua users -"
    "d /home/killua/.cache/claude-kit/sources 0755 killua users -"
    "d /var/lib/cronicle 0700 root root -"
    "d /var/lib/cronicle/state 0700 root root -"
  ];

  virtualisation.quadlet.containers.cronicle = {
    autoStart = false;

    containerConfig = {
      image = cronicleImage;
      publishPorts = ["127.0.0.1:3012:3012"];
      volumes =
        [
          "cronicle_data:/opt/cronicle/data:z"
          "cronicle_logs:/opt/cronicle/logs:z"
          "cronicle_plugins:/opt/cronicle/plugins:z"
        ]
        ++ allBindMounts;
      labels = ["io.containers.autoupdate=registry"];
    };

    serviceConfig = {
      Restart = "always";
      TimeoutStartSec = 300;
    };

    unitConfig = {
      Description = "Cronicle - Cron with web UI";
      After = ["network-online.target" "podman.socket" "cronicle-init.service"];
      Requires = ["podman.socket"];
      Wants = ["cronicle-init.service"];
    };
  };

  # One-shot first-boot setup. Runs against the data volume with no
  # Cronicle daemon attached (storage-cli.js refuses otherwise) to seed
  # the default admin user + categories + plugins via `control.sh setup`.
  # Idempotent: `control.sh setup` short-circuits with "Storage has
  # already been set up." on a populated volume, which we tolerate.
  systemd.services.cronicle-init = {
    description = "Cronicle first-boot setup";
    wantedBy = ["multi-user.target"];
    before = ["cronicle.service"];
    path = [pkgs.podman pkgs.coreutils];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -eu
      install -d -m 0700 /var/lib/cronicle /var/lib/cronicle/state

      if [ -f /var/lib/cronicle/.setup-done ]; then
        echo "[init] setup sentinel present, skipping"
        exit 0
      fi

      # Stop any running cronicle container — storage-cli holds the data
      # lock and refuses while the daemon is up.
      podman stop cronicle >/dev/null 2>&1 || true

      podman run --rm \
        -v cronicle_data:/opt/cronicle/data:z \
        -v cronicle_logs:/opt/cronicle/logs:z \
        -v cronicle_plugins:/opt/cronicle/plugins:z \
        ${cronicleImage} /opt/cronicle/bin/control.sh setup || true

      touch /var/lib/cronicle/.setup-done
      echo "[init] setup complete"
    '';
  };

  systemd.services.cronicle-bootstrap = {
    description = "Sync Cronicle events with modules/containers/cronicle/events/";
    # Tied to cronicle.service rather than multi-user.target so it only runs
    # when cronicle is started manually — otherwise `requires` here would drag
    # the cronicle container up at boot, defeating `autoStart = false`.
    wantedBy = ["cronicle.service"];
    after = ["cronicle.service" "cronicle-init.service"];
    requires = ["cronicle.service" "cronicle-init.service"];
    path = [pkgs.curl pkgs.coreutils pkgs.jq];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -eu

      # Wait for Cronicle's web server to come up. /api/app/ping is the
      # cheapest unauthenticated probe.
      for i in $(seq 1 60); do
        if curl -sf -m 2 http://127.0.0.1:3012/api/app/ping >/dev/null 2>&1; then
          break
        fi
        sleep 2
      done

      install -d -m 0700 /var/lib/cronicle/state

      # Log in as the built-in admin user to grab a session_id for the
      # subsequent REST calls. Default Cronicle install ships admin/admin;
      # rotating the password via the UI will break this — to support that,
      # plumb the new password through sops and read it here.
      login_resp="$(curl -sS -m 10 -X POST \
        -H 'Content-Type: application/json' \
        --data-binary '{"username":"admin","password":"admin"}' \
        http://127.0.0.1:3012/api/user/login)"
      SESSION_ID="$(printf '%s' "$login_resp" | jq -r '.session_id // empty')"
      if [ -z "$SESSION_ID" ]; then
        echo "[bootstrap] login failed: $login_resp"
        exit 1
      fi

      ${concatStringsSep "\n" (map mkSyncCmd eventPayloads)}

      echo "[bootstrap] event sync complete"
    '';
  };
}
