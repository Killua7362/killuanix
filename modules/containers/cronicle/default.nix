# Cronicle — declarative cron with web UI, reachable at http://localhost:3012.
#
# Web UI controls: "Active" toggle (pause/resume), "Run Now", live log on the
# Job Details tab + history on Completed Jobs, Abort on running jobs.
#
# Default credentials on first boot are admin/admin — change via the UI on
# first login. Cronicle has no REST login endpoint and no env-var hook for
# auto-rotating the admin password, so sops integration is intentionally
# skipped (the data lives in the cronicle_data volume).
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
#   Disabled events are NOT removed from Cronicle — they're seeded with the
#   `enabled: 0` Cronicle field, so they show up in the schedule list with
#   the "Active" checkbox off (greyed-out / not firing). This keeps history,
#   notes, and the event itself visible in the UI for easy re-enabling.
#
#   cronicle-bootstrap.service runs on every activation. For each event it
#   compares the per-event state at /opt/cronicle/data/.bootstrap/<id>.state
#   to the desired state derived from `enabled`:
#
#     desired=active    + state missing/"inactive"     -> add_event(enabled=1), state:=active
#     desired=active    + state="active"               -> no-op (UI tweaks preserved)
#     desired=inactive  + state missing/"active"       -> re-seed with enabled=0, state:=inactive
#     desired=inactive  + state="inactive"             -> no-op
#
#   So toggling `enabled` in nix is what flips the Active checkbox; pausing
#   the event from the UI on an active-in-nix event is sticky across rebuilds
#   because we don't re-touch when the sentinel matches the desired state.
{pkgs, ...}: let
  inherit (builtins) attrNames filter map readDir toJSON;
  inherit (pkgs.lib) hasSuffix concatMap unique optionalAttrs concatStringsSep;

  eventsDir = ./events;

  eventFiles = filter (n: hasSuffix ".nix" n) (attrNames (readDir eventsDir));

  loaded = map (f: import (eventsDir + "/${f}")) eventFiles;

  # All bind-mount specs requested by enabled events, deduplicated. Disabled
  # events keep their host paths off the container — there's no reason to
  # expose them when the script can't run anyway, and re-enabling will add
  # the mount back on the next rebuild.
  enabledForMounts = filter (e: e.enabled or true) loaded;
  allBindMounts = unique (concatMap (e: e.bindMounts or []) enabledForMounts);

  toCronicleJSON = e:
    toJSON ({
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
      // optionalAttrs (e ? notes) {notes = e.notes;});

  eventPayloads =
    map (e: {
      inherit (e) id;
      desired =
        if (e.enabled or true)
        then "active"
        else "inactive";
      json = toCronicleJSON e;
    })
    loaded;

  # Single-quote-safe escape for embedding the JSON in a bash heredoc-free
  # `printf '%s' '...'` line. toJSON never emits literal single quotes in
  # our event shape (script bodies go through JSON-string escaping), but
  # the escape is here defensively for arbitrary future events.
  shEscape = s: builtins.replaceStrings ["'"] ["'\\''"] s;

  mkSyncCmd = p: ''
    echo "[bootstrap] event ${p.id}: desired=${p.desired}"
    state="$(podman exec cronicle sh -c 'cat /opt/cronicle/data/.bootstrap/${p.id}.state 2>/dev/null || true')"
    if [ "$state" = "${p.desired}" ]; then
      echo "[bootstrap] event ${p.id}: already in desired state, leaving Cronicle alone"
    else
      echo "[bootstrap] event ${p.id}: syncing (was '$state')"
      # Idempotent re-seed: delete first (ignore failure if absent), then add
      # with the new enabled flag. This loses any UI edits to params/timing
      # for this event when nix flips the enabled flag — by design, since
      # the user is asking for the nix-declared shape on toggle.
      podman exec cronicle node /opt/cronicle/bin/storage-cli.js delete_event ${p.id} >/dev/null 2>&1 || true
      printf '%s' '${shEscape p.json}' \
        | podman exec -i cronicle node /opt/cronicle/bin/storage-cli.js add_event
      podman exec cronicle sh -c 'printf %s ${p.desired} > /opt/cronicle/data/.bootstrap/${p.id}.state'
    fi
  '';
in {
  systemd.tmpfiles.rules = [
    "d /home/killua/.cache/claude-kit 0755 killua users -"
    "d /home/killua/.cache/claude-kit/sessions 0755 killua users -"
    "d /home/killua/.cache/claude-kit/sources 0755 killua users -"
  ];

  virtualisation.quadlet.containers.cronicle = {
    autoStart = true;

    containerConfig = {
      image = "docker.io/soulteary/cronicle:v0.9.16";
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
      After = ["network-online.target" "podman.socket"];
      Requires = ["podman.socket"];
    };
  };

  systemd.services.cronicle-bootstrap = {
    description = "Sync Cronicle events with modules/containers/cronicle/events/";
    wantedBy = ["multi-user.target"];
    after = ["cronicle.service"];
    requires = ["cronicle.service"];
    path = [pkgs.podman pkgs.coreutils pkgs.curl];
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

      # First-boot defaults (no-op on a populated volume): admin/admin user,
      # built-in categories, plugins, server groups.
      podman exec cronicle /opt/cronicle/bin/control.sh setup || true

      # Per-event state lives under .bootstrap/ in the data volume.
      podman exec cronicle mkdir -p /opt/cronicle/data/.bootstrap

      ${concatStringsSep "\n" (map mkSyncCmd eventPayloads)}

      echo "[bootstrap] event sync complete"
    '';
  };
}
