# Gaming stack — Steam, Gamescope, Game Mode, Jovian autostart
{
  config,
  lib,
  pkgs,
  ...
}: {
  # ── Steam ──
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    gamescopeSession.enable = true;
  };

  # ── Gamescope ──
  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };

  # ── Jovian Steam UI — autostart into Game Mode ──
  jovian.steam = {
    enable = true;
    autoStart = true;
    user = "killua";
    desktopSession = "plasma"; # "Return to Desktop" switches to Plasma
  };

  # ── Auto-login via SDDM ──
  services.displayManager.autoLogin = {
    enable = true;
    user = "killua";
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

  # ── Gaming packages ──
  environment.systemPackages = with pkgs; [
    mangohud
    gamescope
    protonup-qt
    lutris
    heroic
  ];
}
