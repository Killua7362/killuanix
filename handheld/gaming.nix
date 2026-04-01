# Gaming stack — Steam, Gamescope, Game Mode, session management
#
# Change `defaultSession` below to control what boots on startup.
# Valid values:
#   "gamescope-wayland"  — Steam Game Mode (Steam Deck-like)
#   "hyprland"           — Hyprland compositor
#   "plasma"             — KDE Plasma desktop
#
# All three sessions are always available from SDDM login screen.
# Auto-login boots directly into whichever session is set below.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  # ╔══════════════════════════════════════════════════════════════╗
  # ║  DEFAULT BOOT SESSION — change this one line to switch       ║
  # ║  Options: "gamescope-wayland" | "hyprland" | "plasma"        ║
  # ╚══════════════════════════════════════════════════════════════╝
  defaultSession = "gamescope-wayland";

  # Session switch script — switch between sessions from any desktop/TTY
  session-switch = pkgs.writeShellScriptBin "session-switch" ''
    usage() {
      echo "Usage: session-switch <plasma|hyprland|gaming>"
      echo ""
      echo "  plasma    — Switch to KDE Plasma desktop"
      echo "  hyprland  — Switch to Hyprland compositor"
      echo "  gaming    — Switch to Steam Game Mode (gamescope)"
      echo ""
      echo "Current default boot session: ${defaultSession}"
      echo "To change the boot default, edit defaultSession in gaming.nix and rebuild."
      exit 1
    }

    if [ $# -ne 1 ]; then
      usage
    fi

    case "$1" in
      plasma)
        echo "Switching to Plasma desktop..."
        steamosctl set-default-desktop-session plasma.desktop 2>/dev/null || true
        steamosctl switch-to-desktop-mode 2>/dev/null || true
        ;;
      hyprland)
        echo "Switching to Hyprland..."
        steamosctl set-default-desktop-session hyprland.desktop 2>/dev/null || true
        steamosctl switch-to-desktop-mode 2>/dev/null || true
        ;;
      gaming|gamescope|steam)
        echo "Switching to Steam Game Mode..."
        steamosctl switch-to-game-mode 2>/dev/null || true
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

  # ── Jovian Steam UI — autoStart enables steamos-manager + "Switch to Desktop" ──
  # NOTE: Do NOT enable programs.steam.gamescopeSession or programs.gamescope —
  # Jovian handles gamescope, its session, and cap_sys_nice wrapper internally.
  jovian.steam = {
    enable = true;
    autoStart = true;
    user = "killua";
    desktopSession = "hyprland-uwsm"; # "Return to Desktop" from Game Mode goes here
    # Plasma gives a black screen on Intel MSI Claw — Hyprland works.
    # To try plasma again: change to "plasma" and rebuild.
    # Verify session names with: ls /run/current-system/sw/share/wayland-sessions/

    # Intel GPU environment for gamescope session
    environment = {
      INTEL_DEBUG = "noccs"; # Fixes color corruption on Intel Arc
      LIBVA_DRIVER_NAME = "iHD";
    };
  };

  # ── Override Jovian's hardcoded defaultSession so we can boot into any session ──
  # Jovian sets defaultSession = "gamescope-wayland" internally; we override it here.
  services.displayManager.defaultSession = lib.mkForce defaultSession;

  # ── Fix: Make /etc/sddm.conf.d writable for steamos-manager ──
  # NixOS turns /etc/sddm.conf.d into a read-only Nix store symlink.
  # steamos-manager needs to write zzt-steamos-temp-login.conf there
  # for "Switch to Desktop" to work.

  # 1) Activation script: replaces the symlink after every nixos-rebuild
  system.activationScripts.sddmConfWritable = lib.stringAfter ["etc"] ''
    if [ -L /etc/sddm.conf.d ]; then
      target=$(readlink -f /etc/sddm.conf.d)
      rm /etc/sddm.conf.d
      mkdir -p /etc/sddm.conf.d
      cp -aL "$target"/. /etc/sddm.conf.d/ 2>/dev/null || true
    fi
    # Ensure the directory (whether new or existing) is writable
    chmod 755 /etc/sddm.conf.d 2>/dev/null || true
  '';

  # 2) Boot service: catches cases where the activation script didn't run
  #    (e.g. reboot without rebuild). Runs before SDDM starts.
  systemd.services.sddm-conf-writable = {
    description = "Ensure /etc/sddm.conf.d is a writable directory for steamos-manager";
    wantedBy = ["multi-user.target"];
    before = ["display-manager.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      if [ -L /etc/sddm.conf.d ]; then
        target=$(readlink -f /etc/sddm.conf.d)
        rm /etc/sddm.conf.d
        mkdir -p /etc/sddm.conf.d
        cp -aL "$target"/. /etc/sddm.conf.d/ 2>/dev/null || true
      fi
      chmod 755 /etc/sddm.conf.d 2>/dev/null || true
    '';
  };

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

  # ── Gaming packages + session-switch tool ──
  environment.systemPackages = with pkgs; [
    mangohud
    protonup-qt
    lutris
    heroic
    session-switch
  ];
}
