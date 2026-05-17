# Synapse — the Matrix homeserver, reachable at http://127.0.0.1:8008.
#
# Architecture:
#   - matrix_synapse_data volume holds the homeserver.yaml that synapse's own
#     `generate` mode produces on first boot (signing key, macaroon secret,
#     registration shared secret, form secret, log config). Those secrets are
#     LIVE STATE, not sops — losing the volume rotates the homeserver's
#     identity. Back it up.
#   - synapse-overrides.service renders /run/matrix-synapse/etc/overrides.yaml
#     every boot from nix + sops, swapping the defaults for postgres, killing
#     federation, and wiring in the bridge appservice files.
#   - synapse is started with `--config-path /data/homeserver.yaml --config-path
#     /etc/synapse/overrides.yaml`; later configs win on conflict.
#
# server_name (matrix.killua.local) is IRREVERSIBLE after first boot. To
# change it: wipe matrix_synapse_data + re-register everyone.
{
  pkgs,
  config,
  ...
}: let
  sopsPath = name: config.sops.secrets.${name}.path;

  serverName = "matrix.killua.local";
  synapseImage = "docker.io/matrixdotorg/synapse:latest";

  # Registration files for the four bridges are dropped by each bridge's
  # *-config service into /var/lib/matrix-appservices/. Synapse reads them
  # at /etc/synapse/appservices/ via bind-mount.
  appserviceRegistrations = [
    "/etc/synapse/appservices/telegram.yaml"
    "/etc/synapse/appservices/whatsapp.yaml"
    "/etc/synapse/appservices/meta-instagram.yaml"
    "/etc/synapse/appservices/meta-messenger.yaml"
  ];
in {
  # Shared dir bridges drop registration.yaml into and synapse reads.
  systemd.tmpfiles.rules = [
    "d /var/lib/matrix-appservices 0755 root root -"
  ];

  virtualisation.quadlet.containers.synapse = {
    autoStart = false;

    containerConfig = {
      image = synapseImage;
      networks = ["matrix-net"];
      publishPorts = ["127.0.0.1:8008:8008"];
      volumes = [
        "matrix_synapse_data:/data:z"
        "/run/matrix-synapse/etc:/etc/synapse:ro"
        "/var/lib/matrix-appservices:/etc/synapse/appservices:ro,z"
      ];
      environments = {
        SYNAPSE_CONFIG_PATH = "/data/homeserver.yaml";
        # Pass our overrides via the run wrapper's exec args below.
      };
      # The official entrypoint script runs `python -m synapse.app.homeserver`
      # honoring SYNAPSE_CONFIG_PATH + extra args. Append our overrides.
      exec = "run --config-path=/etc/synapse/overrides.yaml";
      labels = ["io.containers.autoupdate=registry"];
    };

    serviceConfig = {
      Restart = "always";
      TimeoutStartSec = 300;
    };

    unitConfig = {
      Description = "Synapse Matrix Homeserver";
      After = [
        "network-online.target"
        "podman.socket"
        "matrix-postgres-ready.service"
        "synapse-generate.service"
        "synapse-overrides.service"
        "mautrix-telegram-config.service"
        "mautrix-whatsapp-config.service"
        "mautrix-meta-instagram-config.service"
        "mautrix-meta-messenger-config.service"
      ];
      Requires = [
        "podman.socket"
        "matrix-postgres-ready.service"
        "synapse-generate.service"
        "synapse-overrides.service"
        "mautrix-telegram-config.service"
        "mautrix-whatsapp-config.service"
        "mautrix-meta-instagram-config.service"
        "mautrix-meta-messenger-config.service"
      ];
    };
  };

  # One-shot first-boot generation of /data/homeserver.yaml + signing key +
  # log config. Idempotent: the image's generate mode skips existing files.
  # Sentinel-guarded so we don't pay the podman startup cost every boot.
  systemd.services.synapse-generate = {
    description = "Synapse first-boot key + base config generation";
    wantedBy = ["multi-user.target"];
    before = ["synapse.service"];
    path = [pkgs.podman pkgs.coreutils];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -eu
      install -d -m 0700 /var/lib/matrix-state
      if [ -f /var/lib/matrix-state/.synapse-generated-v1 ]; then
        echo "synapse base config already generated; skipping"
        exit 0
      fi

      podman run --rm \
        -v matrix_synapse_data:/data:z \
        -e SYNAPSE_SERVER_NAME=${serverName} \
        -e SYNAPSE_REPORT_STATS=no \
        ${synapseImage} generate

      touch /var/lib/matrix-state/.synapse-generated-v1
      echo "synapse base config generated"
    '';
  };

  # Render /run/matrix-synapse/etc/overrides.yaml every boot. Substitutes the
  # postgres password from sops at runtime so it never lands in the nix store.
  systemd.services.synapse-overrides = {
    description = "Render Synapse override config from nix + sops";
    wantedBy = ["multi-user.target"];
    before = ["synapse.service"];
    after = ["synapse-generate.service"];
    requires = ["synapse-generate.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      RuntimeDirectory = "matrix-synapse/etc";
      RuntimeDirectoryMode = "0755";
    };
    script = ''
      set -eu
      umask 022
      SYNAPSE_DB_PW="$(cat ${sopsPath "matrix_synapse_db_password"})"
      REG_SHARED_SECRET="$(cat ${sopsPath "matrix_synapse_registration_secret"})"

      cat > /run/matrix-synapse/etc/overrides.yaml <<EOF
      # Auto-rendered by synapse-overrides.service. Edits will not survive.
      server_name: "${serverName}"
      public_baseurl: "http://127.0.0.1:8008/"
      report_stats: false
      enable_registration: false
      registration_shared_secret: "$REG_SHARED_SECRET"

      # Bind to all interfaces inside the container; podman maps 127.0.0.1:8008.
      listeners:
        - port: 8008
          tls: false
          type: http
          x_forwarded: true
          bind_addresses: ['0.0.0.0']
          resources:
            - names: [client]
              compress: false

      # Federation off — no public exposure, no .well-known, no 8448 listener.
      federation_domain_whitelist: []
      allow_public_rooms_over_federation: false

      database:
        name: psycopg2
        args:
          user: synapse
          password: "$SYNAPSE_DB_PW"
          database: synapse
          host: matrix-postgres
          port: 5432
          cp_min: 5
          cp_max: 10

      app_service_config_files:
      ${builtins.concatStringsSep "\n" (map (p: "  - \"" + p + "\"") appserviceRegistrations)}

      # Encryption: allow E2EE but don't auto-enable for new rooms — bridges
      # can't decrypt incoming user messages without a key-share dance that
      # Element doesn't always complete in time.
      encryption_enabled_by_default_for_room_type: "off"

      # Trust appservice tokens for double-puppeting (MSC4190 path the
      # mautrix Go bridges use).
      experimental_features:
        msc4190_enabled: true

      # Bridges mass-join the user as double-puppet to every portal at startup
      # / sync-chats. Synapse default rate limits 429 the bridge into a retry
      # storm. Crank them up — single-user homeserver, no abuse risk.
      rc_message:
        per_second: 1000
        burst_count: 1000
      rc_joins:
        local:
          per_second: 100
          burst_count: 200
        remote:
          per_second: 100
          burst_count: 200
      rc_joins_per_room:
        per_second: 100
        burst_count: 200
      rc_invites:
        per_room:
          per_second: 100
          burst_count: 200
        per_user:
          per_second: 100
          burst_count: 200
        per_issuer:
          per_second: 100
          burst_count: 200
      rc_admin_redaction:
        per_second: 100
        burst_count: 200
      rc_login:
        address:
          per_second: 10
          burst_count: 30
        account:
          per_second: 10
          burst_count: 30
        failed_attempts:
          per_second: 1
          burst_count: 5

      media_store_path: /data/media_store
      max_upload_size: 4G

      # Synapse 1.120+ defaults enable_authenticated_media to true, which
      # 404s the legacy /_matrix/media/v3/download path. Element web 1.12
      # advertises support but still falls back to the legacy URL for some
      # uploads — flip to false so unauthenticated downloads work.
      enable_authenticated_media: false

      log_config: "/data/${serverName}.log.config"
      signing_key_path: "/data/${serverName}.signing.key"
      EOF

      chmod 0644 /run/matrix-synapse/etc/overrides.yaml
    '';
  };
}
