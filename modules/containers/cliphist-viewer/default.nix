# cliphist-viewer — browser DB viewer for the cliphist clipboard store.
#
# A tiny stdlib http.server (viewer.py) that renders every cliphist entry as an
# HTML grid — text + decoded image thumbnails — and copies an entry back to the
# Wayland clipboard (mime-detected wl-copy) when clicked. Loopback-only on
# 127.0.0.1:8899.
#
# It is a **system** unit (not an HM user service) so the service-bridge daemon
# (which drives Glance's Home "Services" tile + Containers tab) can start/stop it
# via root's `systemctl` — service-bridge cannot reach `systemctl --user` units.
# It runs *as* the killua user with HOME/XDG_RUNTIME_DIR/WAYLAND_DISPLAY wired up
# so it can read ~/.cache/cliphist/db and reach the live Wayland clipboard.
#
# No `wantedBy` → installed but NOT started at boot. Bring it up from the Glance
# Containers tab (Start button) or `sudo systemctl start cliphist-viewer`, then
# open http://localhost:8899 (the Services-tile / Containers link).
#
# NOTE: the clipboard history can contain secrets (e.g. values copied via
# clipboard-menu). Loopback-only + on-demand start is the boundary; don't expose
# the port.
{pkgs, ...}: let
  uid = 1000;
  user = "killua";
  port = 8899;

  # Stage viewer.py into its own dir (a bare ./viewer.py store path has
  # /nix/store as its dirname, which is awkward to reference).
  viewerDir = pkgs.runCommand "cliphist-viewer-src" {} ''
    mkdir -p $out
    cp ${./viewer.py} $out/viewer.py
  '';

  start = pkgs.writeShellScript "cliphist-viewer-start" ''
    # Discover the live Wayland socket for wl-copy (usually wayland-1).
    for s in "$XDG_RUNTIME_DIR"/wayland-*; do
      case "$s" in *.lock) continue ;; esac
      if [ -S "$s" ]; then
        WAYLAND_DISPLAY=''${s##*/}
        export WAYLAND_DISPLAY
        break
      fi
    done
    exec ${pkgs.python3}/bin/python3 ${viewerDir}/viewer.py
  '';
in {
  systemd.services.cliphist-viewer = {
    description = "cliphist clipboard web viewer (Glance-controlled, no autostart)";
    after = ["graphical-session.target"];
    # Deliberately no wantedBy: never auto-starts; started on demand from Glance.

    path = with pkgs; [cliphist wl-clipboard file coreutils];

    environment = {
      CLIPHIST_VIEWER_HOST = "127.0.0.1";
      CLIPHIST_VIEWER_PORT = toString port;
      HOME = "/home/${user}";
      XDG_RUNTIME_DIR = "/run/user/${toString uid}";
    };

    serviceConfig = {
      Type = "simple";
      User = user;
      ExecStart = start;
      Restart = "on-failure";
      RestartSec = 3;
    };
  };
}
