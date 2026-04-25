# Linkding — self-hosted bookmark manager, reachable at http://localhost:9090.
# Single-container with SQLite (no external DB needed). Data persists in the
# `linkding_data` named volume (declared in modules/containers/default.nix).
#
# Fully sops-driven setup:
#   - linkding-env.service writes /run/linkding/env from sops secrets
#     (LD_SUPERUSER_NAME / LD_SUPERUSER_PASSWORD); linkding's container init
#     auto-creates the admin user on first start.
#   - linkding-import.service runs once per fresh data volume to import the
#     sops-encrypted Netscape bookmark export into the admin's account, then
#     writes a marker so it becomes a no-op on subsequent boots.
#
# Browser extension: install "Linkding Extension" from AMO and point it at
# http://localhost:9090 with an API token from Settings → Integrations.
{
  pkgs,
  config,
  ...
}: let
  sopsPath = name: config.sops.secrets.${name}.path;
  adminUser = "admin";
in {
  virtualisation.quadlet.containers.linkding = {
    autoStart = true;

    containerConfig = {
      image = "docker.io/sissbruecker/linkding:latest";
      publishPorts = [
        "9090:9090"
      ];
      volumes = [
        "linkding_data:/etc/linkding/data:z"
      ];
      environmentFiles = ["/run/linkding/env"];
      labels = [
        "io.containers.autoupdate=registry"
      ];
    };

    serviceConfig = {
      Restart = "always";
      TimeoutStartSec = 300;
    };

    unitConfig = {
      Description = "Linkding - Self-hosted bookmark manager";
      After = [
        "network-online.target"
        "podman.socket"
        "linkding-env.service"
      ];
      Requires = [
        "podman.socket"
        "linkding-env.service"
      ];
    };
  };

  # Stage admin credentials into an env file the container reads. linkding
  # consumes LD_SUPERUSER_NAME / LD_SUPERUSER_PASSWORD on first start to
  # create the admin user (no-op if user already exists).
  systemd.services.linkding-env = {
    description = "Assemble Linkding env file from sops secrets";
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      RuntimeDirectory = "linkding";
      RuntimeDirectoryMode = "0700";
    };
    script = ''
      umask 077
      {
        printf 'LD_SUPERUSER_NAME=%s\n' '${adminUser}'
        printf 'LD_SUPERUSER_PASSWORD=%s\n' "$(cat ${sopsPath "linkding_admin_password"})"
      } > /run/linkding/env
    '';
  };

  # One-shot bookmark seed. Idempotent via /etc/linkding/data/.bookmarks-seeded
  # marker inside the persisted volume. Re-runs only when the volume is empty
  # (i.e. fresh install / volume reset).
  systemd.services.linkding-import = {
    description = "Seed Linkding with sops-encrypted bookmark export";
    wantedBy = ["multi-user.target"];
    after = ["linkding.service"];
    requires = ["linkding.service"];
    path = [pkgs.podman pkgs.coreutils];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -eu

      # Skip if already seeded for this data volume.
      if podman exec linkding test -f /etc/linkding/data/.bookmarks-seeded; then
        echo "linkding bookmarks already seeded; skipping"
        exit 0
      fi

      # Wait for Django + initial migrations + LD_SUPERUSER auto-create to settle.
      for i in $(seq 1 60); do
        if podman exec linkding python manage.py shell -c \
             "from django.contrib.auth import get_user_model; \
              import sys; \
              sys.exit(0 if get_user_model().objects.filter(username='${adminUser}').exists() else 1)" \
             >/dev/null 2>&1; then
          break
        fi
        sleep 2
      done

      # Copy the decrypted bookmarks file into the container and import.
      podman cp ${sopsPath "linkding_bookmarks_html"} linkding:/tmp/seed.html
      podman exec linkding python manage.py import_netscape /tmp/seed.html '${adminUser}'
      podman exec linkding rm -f /tmp/seed.html

      # Flip the admin's UI to dark mode so the first login matches the rest
      # of the desktop. Uses Linkding's own UserProfile model (theme: 'auto'/'light'/'dark').
      podman exec linkding python manage.py shell -c \
        "from django.contrib.auth import get_user_model; \
         u = get_user_model().objects.get(username='${adminUser}'); \
         p = u.profile; p.theme = 'dark'; p.save()" || true

      podman exec linkding touch /etc/linkding/data/.bookmarks-seeded
      echo "linkding bookmarks imported"
    '';
  };
}
