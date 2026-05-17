# Cockpit — web GUI for systemd services + podman containers.
#
# Loopback-only on :9091 (9090 is karakeep). Login is local-user PAM, so the
# `killua` user must have a password set (`passwd`) — SSH-key-only users
# cannot reach the web UI.
#
# Covers every systemd unit on the host with status, start/stop/restart, and
# live journalctl — complements service-bridge (curated allowlist driving the
# Glance tiles) without replacing it.
{
  pkgs,
  lib,
  ...
}: {
  services.cockpit = {
    enable = true;
    port = 9091;
    openFirewall = false;
    settings = {
      WebService = {
        # Loopback HTTP only — no TLS termination needed.
        AllowUnencrypted = true;
        # Upstream module sets Origins from `port`; mkForce to add http + 127.0.0.1.
        Origins = lib.mkForce "https://localhost:9091 http://localhost:9091 http://127.0.0.1:9091";
      };
    };
  };

  # Default cockpit.socket (shipped by the cockpit package via systemd.packages)
  # binds [::]:9090. Upstream NixOS module clears it with an empty-string entry
  # then re-adds the configured port on all interfaces — we mkForce the whole
  # list to keep the clear but restrict the bind to loopback.
  systemd.sockets.cockpit.listenStreams = lib.mkForce ["" "127.0.0.1:9091"];

  # Containers tab — drives the rootful /run/podman/podman.sock that quadlet
  # already provides.
  environment.systemPackages = [pkgs.cockpit-podman];
}
