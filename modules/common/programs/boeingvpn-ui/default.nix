# Boeing VPN browser-UI — Home Manager half.
#
# Packages a tiny Python HTTP daemon (daemon.py) that fronts `openconnect`
# + `ocproxy` (the same pair driven by the `boeingvpn` zsh function), and
# serves a static frontend simulating a Windows window. Runs as a systemd
# *user* service on http://127.0.0.1:7777, started on login.
#
# The Chrome ManagedBookmarks policy that drops a bookmark to this URL is
# system-scoped — see ./nixos.nix, which chrollo/killua import directly.
{
  pkgs,
  lib,
  ...
}: let
  staticAssets = pkgs.runCommand "boeingvpn-ui-static" {} ''
    mkdir -p $out
    cp ${./static}/* $out/
  '';

  daemon = pkgs.replaceVars ./daemon.py {
    python3 = pkgs.python3;
    openconnect = pkgs.openconnect;
    ocproxy = pkgs.ocproxy;
    static = staticAssets;
  };

  boeingvpnUi =
    pkgs.runCommand "boeingvpn-ui" {
      nativeBuildInputs = [pkgs.makeWrapper];
    } ''
      install -Dm755 ${daemon} $out/bin/boeingvpn-ui
      patchShebangs $out/bin/boeingvpn-ui
    '';
in {
  home.packages = lib.optionals pkgs.stdenv.isLinux [boeingvpnUi];

  systemd.user.services.boeingvpn-ui = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Boeing VPN browser UI daemon";
      After = ["graphical-session.target"];
    };
    Service = {
      ExecStart = "${boeingvpnUi}/bin/boeingvpn-ui";
      Restart = "on-failure";
      RestartSec = 3;
      # Daemon spawns openconnect; ensure SIGTERM cascades to the whole group.
      KillMode = "control-group";
      # If the daemon's own shutdown ever hangs, don't let systemctl restart
      # block the terminal — escalate to SIGKILL after 5s.
      TimeoutStopSec = 5;
    };
    Install.WantedBy = ["default.target"];
  };
}
