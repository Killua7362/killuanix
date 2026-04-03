# Gaming stack — Steam, Gamescope, Game Mode, session management
#
# Session switching uses a .next-session file mechanism:
#   - SDDM auto-logs into "session-dispatch" which reads ~/.next-session
#   - If ~/.next-session contains "plasma" or "hyprland", launches that desktop
#   - If no ~/.next-session exists, launches gamescope (Steam Game Mode)
#   - "Switch to Desktop" in Steam writes ~/.next-session and logs out
#   - SDDM re-logs and the dispatcher picks up the new session
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
  # A fake "session" that SDDM auto-logs into. It reads ~/.next-session
  # to decide whether to launch gamescope or a desktop environment.
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
          case "$session" in
            plasma)
              exec startplasma-wayland
              ;;
            hyprland)
              exec Hyprland
              ;;
          esac
        fi
        # Default: launch gamescope
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

      # Ensure session launchers are in PATH
      wrapProgram $out/bin/session-dispatch-start \
        --prefix PATH : "${lib.makeBinPath [
        pkgs.gamescope-session # start-gamescope-session
        pkgs.kdePackages.plasma-workspace # startplasma-wayland
        inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland # Hyprland
        pkgs.coreutils
      ]}"

      mkdir -p $out/share/wayland-sessions
      cp ${desktopFile} $out/share/wayland-sessions/session-dispatch.desktop

      runHook postInstall
    '';

    passthru.providedSessions = ["session-dispatch"];
  };

  # ── steamos-session-select override ──
  # Steam calls `steamos-session-select plasma` for "Switch to Desktop"
  # and `steamos-session-select gamescope` for "Return to Gaming Mode".
  # This replaces the jovian-stubs version that relies on steamosctl.
  steamos-session-select-override = pkgs.writeShellScriptBin "steamos-session-select" ''
    case "$1" in
      plasma)
        echo "plasma" > "$HOME/.next-session"
        ;;
      gamescope)
        rm -f "$HOME/.next-session"
        ;;
      *)
        # Any other desktop switch request defaults to plasma
        echo "plasma" > "$HOME/.next-session"
        ;;
    esac
    sync
    # Terminate the current session so SDDM re-logs
    loginctl terminate-session "$XDG_SESSION_ID" 2>/dev/null || true
  '';

  # ── Return to Gaming Mode ──
  # Desktop entry + script for switching back from desktop to gamescope
  return-to-gaming = let
    script = pkgs.writeShellScriptBin "return-to-gaming-mode" ''
      rm -f "$HOME/.next-session"
      case "$XDG_CURRENT_DESKTOP" in
        Hyprland|hyprland)
          hyprctl dispatch exit
          ;;
        KDE)
          qdbus org.kde.Shutdown /Shutdown logout 2>/dev/null || \
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
        loginctl terminate-session "$XDG_SESSION_ID" 2>/dev/null || true
        ;;
      hyprland)
        echo "Switching to Hyprland..."
        echo "hyprland" > "$HOME/.next-session"
        loginctl terminate-session "$XDG_SESSION_ID" 2>/dev/null || true
        ;;
      gaming|gamescope|steam)
        echo "Switching to Steam Game Mode..."
        rm -f "$HOME/.next-session"
        loginctl terminate-session "$XDG_SESSION_ID" 2>/dev/null || true
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
  # autoStart enables SDDM auto-login + steamos-manager for hardware management.
  # Session switching is handled by our .next-session mechanism, not steamos-manager.
  jovian.steam = {
    enable = true;
    autoStart = true;
    user = "killua";
    # Set to gamescope-wayland to suppress Jovian warning and make its
    # internal session switching a no-op (we handle it ourselves)
    desktopSession = "gamescope-wayland";

    # Intel GPU environment for gamescope session
    environment = {
      INTEL_DEBUG = "noccs"; # Fixes color corruption on Intel Arc
      LIBVA_DRIVER_NAME = "iHD";
    };
  };

  # ── Session dispatch: SDDM boots into our dispatcher instead of gamescope directly ──
  services.displayManager.defaultSession = lib.mkForce "session-dispatch";
  services.displayManager.sessionPackages = [session-dispatch];

  # ── Disable Jovian's steamosctl-based session switching services ──
  # We replace this with the .next-session file mechanism
  systemd.user.services.jovian-setup-desktop-session.enable = false;

  # ── Override steamos-session-select to use .next-session instead of steamosctl ──
  # meta.priority ensures our version shadows jovian-stubs in PATH
  nixpkgs.overlays = [
    (final: prev: {
      jovian-stubs = prev.jovian-stubs.overrideAttrs (old: {
        buildCommand =
          old.buildCommand
          + ''
            # Remove the steamos-session-select stub — we provide our own
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

  # ── Gaming packages + session tools ──
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
