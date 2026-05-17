# Matrix-postgres — dedicated Postgres 16 instance backing Synapse and the four
# mautrix bridges. Separate from boeing-postgres so the two stacks can never
# step on each other's roles, port (we don't publish a host port), or volume.
#
# First-boot init runs /docker-entrypoint-initdb.d/init-matrix.sh against an
# empty data volume. It reads env vars staged from sops by matrix-postgres-env
# and creates one role + database per consumer:
#
#   synapse                -> db "synapse" with C collation (required by synapse)
#   mautrix_telegram       -> db "mautrix_telegram"
#   mautrix_whatsapp       -> db "mautrix_whatsapp"
#   mautrix_meta_instagram -> db "mautrix_meta_instagram"
#   mautrix_meta_messenger -> db "mautrix_meta_messenger"
#
# Recreating the role/db set requires wiping the volume:
#   sudo systemctl stop matrix-postgres
#   sudo podman volume rm matrix_postgres_data
#   sudo systemctl start matrix-postgres
{
  pkgs,
  config,
  ...
}: let
  sopsPath = name: config.sops.secrets.${name}.path;

  # Plain text (non-executable) — postgres entrypoint detects .sh files and
  # sources them when not executable, exec'ing them when executable. We use
  # source mode because nix-store shebangs (#!/nix/store/.../bash) don't
  # resolve inside the Debian-based postgres container.
  initScript = pkgs.writeText "matrix-postgres-init.sh" ''
    set -eu

    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<EOSQL
      CREATE ROLE synapse WITH LOGIN PASSWORD '$MATRIX_SYNAPSE_DB_PASSWORD';
      CREATE DATABASE synapse
        WITH OWNER synapse
             TEMPLATE template0
             LC_COLLATE 'C'
             LC_CTYPE   'C';

      CREATE ROLE mautrix_telegram WITH LOGIN PASSWORD '$MATRIX_BRIDGE_TELEGRAM_DB_PASSWORD';
      CREATE DATABASE mautrix_telegram WITH OWNER mautrix_telegram;

      CREATE ROLE mautrix_whatsapp WITH LOGIN PASSWORD '$MATRIX_BRIDGE_WHATSAPP_DB_PASSWORD';
      CREATE DATABASE mautrix_whatsapp WITH OWNER mautrix_whatsapp;

      CREATE ROLE mautrix_meta_instagram WITH LOGIN PASSWORD '$MATRIX_BRIDGE_META_INSTAGRAM_DB_PASSWORD';
      CREATE DATABASE mautrix_meta_instagram WITH OWNER mautrix_meta_instagram;

      CREATE ROLE mautrix_meta_messenger WITH LOGIN PASSWORD '$MATRIX_BRIDGE_META_MESSENGER_DB_PASSWORD';
      CREATE DATABASE mautrix_meta_messenger WITH OWNER mautrix_meta_messenger;
    EOSQL
  '';
in {
  virtualisation.quadlet.containers.matrix-postgres = {
    autoStart = false;

    containerConfig = {
      image = "docker.io/library/postgres:16";
      # No publishPorts: only reachable on the matrix-net podman network.
      networks = ["matrix-net"];
      volumes = [
        "matrix_postgres_data:/var/lib/postgresql/data:z"
        "${initScript}:/docker-entrypoint-initdb.d/init-matrix.sh:ro,z"
      ];
      environments = {
        POSTGRES_USER = "matrix";
        POSTGRES_DB = "matrix";
      };
      environmentFiles = ["/run/matrix-postgres/env"];
      labels = ["io.containers.autoupdate=registry"];
    };

    serviceConfig = {
      Restart = "always";
      TimeoutStartSec = 300;
    };

    unitConfig = {
      Description = "Matrix - PostgreSQL 16 (synapse + mautrix bridges)";
      After = [
        "network-online.target"
        "podman.socket"
        "matrix-postgres-env.service"
      ];
      Requires = [
        "podman.socket"
        "matrix-postgres-env.service"
      ];
    };
  };

  # Stage all DB-related sops secrets into one env file for matrix-postgres.
  # POSTGRES_PASSWORD is the superuser; the init script consumes the rest.
  systemd.services.matrix-postgres-env = {
    description = "Assemble matrix-postgres env file from sops secrets";
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      RuntimeDirectory = "matrix-postgres";
      RuntimeDirectoryMode = "0700";
    };
    script = ''
      umask 077
      {
        printf 'POSTGRES_PASSWORD=%s\n'                       "$(cat ${sopsPath "matrix_postgres_password"})"
        printf 'MATRIX_SYNAPSE_DB_PASSWORD=%s\n'              "$(cat ${sopsPath "matrix_synapse_db_password"})"
        printf 'MATRIX_BRIDGE_TELEGRAM_DB_PASSWORD=%s\n'      "$(cat ${sopsPath "matrix_bridge_telegram_db_password"})"
        printf 'MATRIX_BRIDGE_WHATSAPP_DB_PASSWORD=%s\n'      "$(cat ${sopsPath "matrix_bridge_whatsapp_db_password"})"
        printf 'MATRIX_BRIDGE_META_INSTAGRAM_DB_PASSWORD=%s\n' "$(cat ${sopsPath "matrix_bridge_meta_instagram_db_password"})"
        printf 'MATRIX_BRIDGE_META_MESSENGER_DB_PASSWORD=%s\n' "$(cat ${sopsPath "matrix_bridge_meta_messenger_db_password"})"
      } > /run/matrix-postgres/env
    '';
  };

  # Readiness gate that downstream services (synapse, bridges) wait on.
  # Polls pg_isready over the matrix-net network from a throwaway container.
  systemd.services.matrix-postgres-ready = {
    description = "Wait for matrix-postgres to accept connections";
    wantedBy = ["multi-user.target"];
    after = ["matrix-postgres.service"];
    requires = ["matrix-postgres.service"];
    path = [pkgs.podman pkgs.coreutils];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      for i in $(seq 1 60); do
        if podman run --rm --network matrix-net docker.io/library/postgres:16 \
             pg_isready -h matrix-postgres -U matrix >/dev/null 2>&1; then
          echo "matrix-postgres ready"
          exit 0
        fi
        sleep 2
      done
      echo "matrix-postgres did not become ready in 120s" >&2
      exit 1
    '';
  };
}
