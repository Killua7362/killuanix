# Gaming stack — Steam, Gamescope, Game Mode, session management
#
# Session switching uses greetd + .next-session file:
#   - greetd auto-logs in and runs the dispatcher script
#   - Dispatcher reads ~/.next-session: if it contains "plasma" or "hyprland",
#     deletes the file and launches that desktop session
#   - If no ~/.next-session exists, launches gamescope (Steam Game Mode)
#   - "Switch to Desktop" in Steam writes ~/.next-session and stops gamescope
#   - gamescope exits → greetd reruns dispatcher → desktop launches
#   - Reboots always go to gamescope because .next-session is deleted on use
#
# Use `session-switch <plasma|hyprland|gaming>` from any session/TTY to switch.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  # ── Session Dispatcher ──
  # greetd runs this on every login. Reads ~/.next-session to decide
  # whether to launch gamescope or a desktop environment.
  # The file is deleted after reading so reboots always default to gamescope.
  session-dispatch = pkgs.writeShellScriptBin "session-dispatch-start" ''
    # Clean up leftover state from any previous session.
    # Without this, switching plasma → gamescope leaves stale/failed
    # systemd user services that prevent gamescope-session from starting
    # (symptoms: gamescope shows black screen with cursor but no Steam).
    ${pkgs.systemd}/bin/systemctl --user reset-failed 2>/dev/null || true
    ${pkgs.systemd}/bin/systemctl --user stop gamescope-session.target 2>/dev/null || true

    # Clear environment variables from previous desktop sessions
    unset QT_QPA_PLATFORM XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP

    NEXT_SESSION="$HOME/.next-session"
    if [ -f "$NEXT_SESSION" ]; then
      session=$(cat "$NEXT_SESSION")
      rm -f "$NEXT_SESSION"
      case "$session" in
        plasma)
          export XDG_CURRENT_DESKTOP=KDE
          export XDG_SESSION_DESKTOP=plasma
          export XDG_SESSION_TYPE=wayland
          exec ${pkgs.kdePackages.plasma-workspace}/bin/startplasma-wayland
          ;;
        hyprland)
          # Launch via UWSM for proper systemd session integration
          exec ${lib.getExe config.programs.uwsm.package} start hyprland-uwsm.desktop
          ;;
      esac
    fi
    # Default: no .next-session file means gamescope
    exec ${pkgs.gamescope-session}/bin/start-gamescope-session
  '';

  # ── steamos-session-select override ──
  # Steam calls this when user clicks "Switch to Desktop" or "Return to Gaming Mode".
  # We write .next-session and cleanly stop the gamescope session.
  # When gamescope exits, greetd automatically reruns the dispatcher.
  steamos-session-select-override = pkgs.writeShellScriptBin "steamos-session-select" ''
    case "$1" in
      plasma)
        echo "plasma" > "$HOME/.next-session"
        ;;
      gamescope)
        rm -f "$HOME/.next-session"
        ;;
      *)
        echo "plasma" > "$HOME/.next-session"
        ;;
    esac
    sync
    # Cleanly stop gamescope — greetd will rerun the dispatcher
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
      echo "  hyprland  - Switch to Hyprland compositor"
      echo "  gaming    - Switch to Steam Game Mode (gamescope)"
      exit 1
    }

    if [ $# -ne 1 ]; then
      usage
    fi

    case "$1" in
      plasma)
        echo "Switching to Plasma desktop..."
        echo "plasma" > "$HOME/.next-session"
        ;;
      hyprland)
        echo "Switching to Hyprland..."
        echo "hyprland" > "$HOME/.next-session"
        ;;
      gaming|gamescope|steam)
        echo "Switching to Steam Game Mode..."
        rm -f "$HOME/.next-session"
        ;;
      *)
        usage
        ;;
    esac
    sync

    # Clean session exit based on what's currently running
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
        # From a TTY or unknown session
        loginctl terminate-session "$XDG_SESSION_ID" 2>/dev/null || true
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
  # enable = true gives us gamescope, steamos-manager, hardware support.
  # autoStart = false disables Jovian's SDDM setup — we use greetd instead.
  jovian.steam = {
    enable = true;
    autoStart = false;
    user = "killua";

    # Intel GPU environment for gamescope session
    # (writes to /etc/xdg/gamescope-session/environment, works without autoStart)
    environment = {
      INTEL_DEBUG = "noccs";
      LIBVA_DRIVER_NAME = "iHD";
    };
  };

  # ── greetd — replaces SDDM for session management ──
  # greetd runs the dispatcher on every login. When the session exits,
  # greetd reruns the dispatcher — no caching, no config file rewriting.
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
  # These are needed for gamescope to work but are lost when autoStart = false.

  # gamescope-session needs a clean PATH (autostart.nix lines 117-141)
  systemd.user.services.gamescope-session = {
    overrideStrategy = "asDropin";
    environment.PATH = lib.mkForce null;
  };

  # Session cleanup on logout (autostart.nix lines 112-115)
  systemd.user.services.steamos-manager-session-cleanup = {
    overrideStrategy = "asDropin";
    wantedBy = ["graphical-session.target"];
  };

  # XDG portal config for gamescope (autostart.nix line 144)
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
