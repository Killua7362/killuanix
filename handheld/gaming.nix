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
  defaultSession = "gamescope";
  desktopSession = "plasma";

  # ── Launch command for each session ──
  launchCmd = session:
    {
      gamescope = "exec ${pkgs.gamescope-session}/bin/start-gamescope-session";
      plasma = ''
        export XDG_CURRENT_DESKTOP=KDE
        export XDG_SESSION_DESKTOP=plasma
        export XDG_SESSION_TYPE=wayland
        exec ${pkgs.kdePackages.plasma-workspace}/bin/startplasma-wayland
      '';
      hyprland = ''
        export XDG_CURRENT_DESKTOP=Hyprland
        export XDG_SESSION_DESKTOP=Hyprland
        export XDG_SESSION_TYPE=wayland
        export XDG_DATA_DIRS="/run/current-system/sw/share:''${XDG_DATA_DIRS:-}"
        exec ${lib.getExe config.programs.uwsm.package} start hyprland-uwsm.desktop
      '';
    }
    .${session};

  # ── Session Dispatcher ──
  # greetd runs this on every login.
  # .next-session (one-shot) overrides the default; deleted after use.
  session-dispatch = pkgs.writeShellScriptBin "session-dispatch-start" ''
    # Clean up leftover state from any previous session
    ${pkgs.systemd}/bin/systemctl --user reset-failed 2>/dev/null || true
    ${pkgs.systemd}/bin/systemctl --user stop gamescope-session.target 2>/dev/null || true

    # Clear environment variables from previous desktop sessions
    unset QT_QPA_PLATFORM XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP

    # One-shot override takes priority
    session="${defaultSession}"
    if [ -f "$HOME/.next-session" ]; then
      session=$(cat "$HOME/.next-session")
      rm -f "$HOME/.next-session"
    fi

    case "$session" in
      plasma)
        ${launchCmd "plasma"}
        ;;
      hyprland)
        ${launchCmd "hyprland"}
        ;;
    esac

    # Fallback: gamescope
    ${launchCmd "gamescope"}
  '';

  # ── steamos-session-select override ──
  # Steam calls this when user clicks "Switch to Desktop".
  # Uses the desktopSession value configured above.
  steamos-session-select-override = pkgs.writeShellScriptBin "steamos-session-select" ''
    case "$1" in
      gamescope)
        rm -f "$HOME/.next-session"
        ;;
      *)
        echo "${desktopSession}" > "$HOME/.next-session"
        ;;
    esac
    sync
    systemctl --user stop gamescope-session.target 2>/dev/null || true
  '';

  # ── Return to Gaming Mode ──
  return-to-gaming = let
    script = pkgs.writeShellScriptBin "return-to-gaming-mode" ''
      rm -f "$HOME/.next-session"
      case "$XDG_CURRENT_DESKTOP" in
        Hyprland|hyprland)
          hyprctl dispatch exit 2>/dev/null || true
          ;;
        KDE)
          qdbus org.kde.Shutdown /Shutdown logout 2>/dev/null || \
          dbus-send --session --type=method_call --dest=org.kde.ksmserver \
            /KSMServer org.kde.KSMServerInterface.logout \
            int32:0 int32:0 int32:0 2>/dev/null || \
          loginctl terminate-session "$XDG_SESSION_ID" 2>/dev/null || true
          ;;
        *)
          loginctl terminate-session "$XDG_SESSION_ID" 2>/dev/null || true
          ;;
      esac
    '';
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
  session-switch = pkgs.writeShellScriptBin "session-switch" ''
    usage() {
      echo "Usage: session-switch <plasma|hyprland|gaming>"
      echo ""
      echo "  plasma    - Switch to KDE Plasma desktop"
      echo "  hyprland  - Switch to Hyprland compositor (UWSM)"
      echo "  gaming    - Switch to Steam Game Mode (gamescope)"
      echo ""
      echo "Config (in gaming.nix):"
      echo "  defaultSession = \"${defaultSession}\"   (boot default)"
      echo "  desktopSession = \"${desktopSession}\"   (Switch to Desktop target)"
      exit 1
    }

    if [ $# -ne 1 ]; then
      usage
    fi

    exit_session() {
      sync
      case "''${XDG_CURRENT_DESKTOP:-}" in
        gamescope)
          systemctl --user stop gamescope-session.target 2>/dev/null || true
          ;;
        Hyprland|hyprland)
          hyprctl dispatch exit 2>/dev/null || true
          ;;
        KDE)
          qdbus org.kde.Shutdown /Shutdown logout 2>/dev/null || \
          loginctl terminate-session "$XDG_SESSION_ID" 2>/dev/null || true
          ;;
        *)
          loginctl terminate-session "$XDG_SESSION_ID" 2>/dev/null || true
          ;;
      esac
    }

    case "$1" in
      plasma)
        echo "Switching to Plasma desktop..."
        echo "plasma" > "$HOME/.next-session"
        exit_session
        ;;
      hyprland)
        echo "Switching to Hyprland..."
        echo "hyprland" > "$HOME/.next-session"
        exit_session
        ;;
      gaming|gamescope|steam)
        echo "Switching to Steam Game Mode..."
        rm -f "$HOME/.next-session"
        exit_session
        ;;
      *)
        usage
        ;;
    esac
  '';
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
