# Gaming stack — Steam, Gamescope, Game Mode, session management
#
# Session switching uses greetd + .next-session file:
#   - greetd auto-logs in and runs the dispatcher script
#   - On boot: launches `defaultSession` (configured below)
#   - "Switch to Desktop" in Steam: writes .next-session with `desktopSession`
#     value, stops gamescope, greetd reruns dispatcher → desktop launches
#   - .next-session is deleted after use, so reboots go back to defaultSession
#
# Configuration:
#   defaultSession  — what boots on startup: "gamescope", "plasma", or "hyprland"
#   desktopSession  — what "Switch to Desktop" switches to: "plasma" or "hyprland"
#
# Use `session-switch <plasma|hyprland|gaming>` to switch sessions at runtime.
#
# Script bodies live as plain `.sh` files under ./scripts/. The wrappers below
# pass nix-injected values (session names, store-path bin locations) via env
# vars set just before exec'ing the script.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  # ╔══════════════════════════════════════════════════════════════╗
  # ║  CONFIGURE THESE                                            ║
  # ╠══════════════════════════════════════════════════════════════╣
  # ║  defaultSession  — boot into this on startup/reboot         ║
  # ║  desktopSession  — "Switch to Desktop" in Steam goes here   ║
  # ║                                                              ║
  # ║  Options: "gamescope" | "plasma" | "hyprland"                ║
  # ╚══════════════════════════════════════════════════════════════╝
  defaultSession = "hyprland";
  desktopSession = "plasma";

  # ── Session Dispatcher ──
  # greetd runs this on every login.
  session-dispatch = pkgs.writeShellApplication {
    name = "session-dispatch-start";
    runtimeInputs = [pkgs.systemd pkgs.coreutils];
    text = ''
      export DEFAULT_SESSION="${defaultSession}"
      export GAMESCOPE_BIN=${pkgs.gamescope-session}/bin/start-gamescope-session
      export PLASMA_BIN=${pkgs.kdePackages.plasma-workspace}/bin/startplasma-wayland
      export UWSM_BIN=${lib.getExe config.programs.uwsm.package}
      exec bash ${./scripts/session-dispatch.sh}
    '';
  };

  # ── steamos-session-select override ──
  # Steam calls this when user clicks "Switch to Desktop".
  steamos-session-select-override = pkgs.writeShellApplication {
    name = "steamos-session-select";
    runtimeInputs = [pkgs.systemd pkgs.coreutils];
    text = ''
      export DESKTOP_SESSION="${desktopSession}"
      exec bash ${./scripts/steamos-session-select.sh} "$@"
    '';
  };

  # ── Return to Gaming Mode ──
  return-to-gaming = let
    script =
      pkgs.writeShellScriptBin "return-to-gaming-mode"
      (builtins.readFile ./scripts/return-to-gaming.sh);
    desktopItem = pkgs.makeDesktopItem {
      name = "return-to-gaming-mode";
      desktopName = "Return to Gaming Mode";
      exec = "return-to-gaming-mode";
      icon = "steam";
      comment = "Switch back to Steam Game Mode (gamescope)";
      categories = ["Game"];
      terminal = false;
    };
  in
    pkgs.symlinkJoin {
      name = "return-to-gaming";
      paths = [script desktopItem];
    };

  # ── Session switch CLI tool ──
  session-switch = pkgs.writeShellApplication {
    name = "session-switch";
    runtimeInputs = [pkgs.systemd pkgs.coreutils];
    text = ''
      export DEFAULT_SESSION="${defaultSession}"
      export DESKTOP_SESSION="${desktopSession}"
      exec bash ${./scripts/session-switch.sh} "$@"
    '';
  };
in {
  # ── Steam ──
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
  };

  # ── Jovian Steam UI ──
  jovian.steam = {
    enable = true;
    autoStart = false;
    user = "killua";

    environment = {
      INTEL_DEBUG = "noccs";
      LIBVA_DRIVER_NAME = "iHD";
    };
  };

  # ── greetd ──
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${session-dispatch}/bin/session-dispatch-start";
        user = "killua";
      };
    };
  };

  # Auto-unlock gnome-keyring so NM's agent-owned wifi secrets don't re-prompt via
  # DMS. NOTE: greetd here is PASSWORDLESS autologin — pam_gnome_keyring gets an
  # empty password, so this only unlocks a keyring whose password is ALSO empty.
  # One-time: delete ~/.local/share/keyrings/* and set the login keyring password
  # to blank (seahorse, or the first secret dialog) so it auto-unlocks headless.
  security.pam.services.greetd.enableGnomeKeyring = true;

  # ── Replicate essential services from Jovian's autoStart ──
  systemd.user.services.gamescope-session = {
    overrideStrategy = "asDropin";
    environment.PATH = lib.mkForce null;
  };

  systemd.user.services.steamos-manager-session-cleanup = {
    overrideStrategy = "asDropin";
    wantedBy = ["graphical-session.target"];
  };

  xdg.portal.configPackages = lib.mkDefault [pkgs.gamescope-session];

  # ── Override steamos-session-select ──
  nixpkgs.overlays = [
    (final: prev: {
      jovian-stubs = prev.jovian-stubs.overrideAttrs (old: {
        buildCommand =
          old.buildCommand
          + ''
            rm -f $out/bin/steamos-session-select
          '';
      });
    })
  ];

  # ── GameMode ──
  programs.gamemode = {
    enable = true;
    settings = {
      general = {
        renice = 10;
        softrealtime = "auto";
        ioprio = 0;
      };
    };
  };

  # ── Environment ──
  environment.sessionVariables = {
    DECKY_USER = "killua";
    DECKY_USER_HOME = "/home/killua";
    QT_QUICK_CONTROLS_STYLE = "org.kde.desktop";
  };

  # ── Packages ──
  environment.systemPackages = with pkgs; [
    mangohud
    protonup-qt
    lutris
    heroic
    session-switch
    steamos-session-select-override
    return-to-gaming
  ];
}
