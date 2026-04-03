# Gaming stack — Steam, Gamescope, Game Mode, session management
#
# Session switching uses a .next-session file mechanism:
#   - SDDM auto-logs into "session-dispatch" which reads ~/.next-session
#   - If ~/.next-session contains "plasma" or "hyprland", it deletes the file
#     and launches that desktop session
#   - If no ~/.next-session exists, launches gamescope (Steam Game Mode)
#   - "Switch to Desktop" writes ~/.next-session and cleanly stops gamescope
#   - SDDM's relogin kicks in and the dispatcher picks up the new session
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
  # SDDM auto-logs into this. It reads ~/.next-session to decide what to launch.
  # The file is deleted after reading so reboots always default to gamescope.
  session-dispatch = pkgs.stdenv.mkDerivation {
    pname = "session-dispatch";
    version = "1.0";

    dontUnpack = true;
    nativeBuildInputs = [pkgs.makeWrapper];

    installPhase = let
      dispatchScript = pkgs.writeScript "session-dispatch-start" ''
        #!/bin/bash
        NEXT_SESSION="$HOME/.next-session"
        if [ -f "$NEXT_SESSION" ]; then
          session=$(cat "$NEXT_SESSION")
          rm -f "$NEXT_SESSION"

          # Let the GPU/DRM settle after the previous compositor released it.
          # Without this pause, the new compositor may fail to acquire DRM master
          # on Intel (Xe) GPUs, causing a black screen.
          sleep 2

          case "$session" in
            plasma)
              export XDG_CURRENT_DESKTOP=KDE
              export XDG_SESSION_DESKTOP=plasma
              export XDG_SESSION_TYPE=wayland
              export QT_QPA_PLATFORM=wayland
              exec dbus-run-session startplasma-wayland
              ;;
            hyprland)
              export XDG_CURRENT_DESKTOP=Hyprland
              export XDG_SESSION_DESKTOP=hyprland
              export XDG_SESSION_TYPE=wayland
              exec Hyprland
              ;;
          esac
        fi
        # Default: no .next-session file means gamescope
        exec start-gamescope-session
      '';
      desktopFile = pkgs.writeText "session-dispatch.desktop" ''
        [Desktop Entry]
        Name=Session Dispatch
        Comment=Auto-dispatch to gamescope or desktop based on ~/.next-session
        Exec=session-dispatch-start
        Type=Application
        DesktopNames=gamescope
      '';
    in ''
      runHook preInstall

      mkdir -p $out/bin
      cp ${dispatchScript} $out/bin/session-dispatch-start
      chmod +x $out/bin/session-dispatch-start

      wrapProgram $out/bin/session-dispatch-start \
        --prefix PATH : "${lib.makeBinPath [
        pkgs.gamescope-session # start-gamescope-session
        pkgs.kdePackages.plasma-workspace # startplasma-wayland
        inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland # Hyprland
        pkgs.dbus # dbus-run-session
        pkgs.coreutils
      ]}"

      mkdir -p $out/share/wayland-sessions
      cp ${desktopFile} $out/share/wayland-sessions/session-dispatch.desktop

      runHook postInstall
    '';

    passthru.providedSessions = ["session-dispatch"];
  };

  # ── steamos-session-select override ──
  # Steam calls this when user clicks "Switch to Desktop" or "Return to Gaming Mode".
  # We write .next-session and cleanly stop the gamescope session target.
  # SDDM's relogin (Relogin=true) automatically starts a new session after exit.
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
    # Cleanly stop gamescope session — this lets gamescope release DRM/GPU
    # resources properly. SDDM's relogin will then start a new session.
    systemctl --user stop gamescope-session.target 2>/dev/null || true
  '';

  # ── Return to Gaming Mode ──
  return-to-gaming = let
    script = pkgs.writeShellScriptBin "return-to-gaming-mode" ''
      rm -f "$HOME/.next-session"
      # Use DE-native logout for clean compositor shutdown
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
        # From a TTY or unknown session — find and kill the graphical session
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
  jovian.steam = {
    enable = true;
    autoStart = true;
    user = "killua";
    desktopSession = "gamescope-wayland";

    environment = {
      INTEL_DEBUG = "noccs";
      LIBVA_DRIVER_NAME = "iHD";
    };
  };

  # ── Session dispatch: SDDM boots into our dispatcher ──
  services.displayManager.defaultSession = lib.mkForce "session-dispatch";
  services.displayManager.sessionPackages = [session-dispatch];

  # ── Disable Jovian's steamosctl-based session switching ──
  systemd.user.services.jovian-setup-desktop-session.enable = false;

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
    session-dispatch
    steamos-session-select-override
    return-to-gaming
  ];
}
