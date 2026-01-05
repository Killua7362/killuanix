{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  userConfig = inputs.self.commonModules.user.userConfig;
  commonPackages = inputs.self.commonModules.packages.commonPackages pkgs inputs;
  terminalPackages = inputs.self.commonModules.packages.terminalPackages pkgs;
  desktopPackages = inputs.self.commonModules.packages.desktopPackages pkgs;
  devPackages = inputs.self.commonModules.packages.devPackages pkgs;
  macPackages = inputs.self.commonModules.packages.macPackages pkgs;
in {
  imports = [
    inputs.self.commonModules.programs
    ../common/programs/hyprland
    ../common/programs/neovim
    ../common/programs/firefox
  ];

  config = {
    # Common system settings
    xdg.enable = true;
    xdg.mime.enable = true;

    # Platform-specific configurations
    nixpkgs.config.allowUnfree = true;

    # Common packages - these will be available on all systems
    home.packages = commonPackages ++ terminalPackages ++ devPackages ++ (if pkgs.stdenv.isLinux then desktopPackages else []) ++ (if pkgs.stdenv.isDarwin then macPackages else []);

    # Platform-specific home directory
    home.username = userConfig.username;
    home.homeDirectory =
      if pkgs.stdenv.isLinux
      then userConfig.homeDirectories.linux
      else if pkgs.stdenv.isDarwin
      then userConfig.homeDirectories.mac
      else "/home/${userConfig.username}";

    # Platform-specific session variables
    home.sessionVariables =
      userConfig.sessionVariables
      // (
        if pkgs.stdenv.isLinux
        then {
          MANPAGER = "nvim +Man!";
          MANWIDTH = "999";
          KEYTIMEOUT = "1";
          LG_CONFIG_FILE = "$HOME/.config/lazygit.yml";
          # XDG_CONFIG_HOME = "$HOME/.config";
          # XDG_DATA_DIRS = "$HOME/.nix-profile/share:$XDG_DATA_DIRS";
        }
        else if pkgs.stdenv.isDarwin
        then {
          TERMINFO_DIRS = "${pkgs.kitty.terminfo.outPath}/share/terminfo";
        }
        else {}
      );

    # Platform-specific services
    services.lorri.enable = lib.mkIf (pkgs.stdenv.isLinux) true;
    services.flatpak.enable = lib.mkIf (pkgs.stdenv.isLinux) true;

    targets.genericLinux.enable = lib.mkIf (pkgs.stdenv.isLinux) true;
    systemd.user.systemctlPath = lib.mkIf (pkgs.stdenv.isLinux) "/bin/systemctl";

    # Flatpak packages (Linux specific)
    services.flatpak.packages = lib.mkIf (pkgs.stdenv.isLinux) [
      "com.logseq.Logseq"
      "com.github.tchx84.Flatseal"
      "com.usebottles.bottles"
      "io.missioncenter.MissionCenter"
      "io.github.limo_app.limo"
      "io.github.fastrizwaan.WineZGUI"
      "com.jetbrains.CLion"
      "org.vinegarhq.Sober"
      "io.github.nozwock.Packet"
    ];

    # Gnome key ring
    services.gnome-keyring.enable = true;
    services.kdeconnect.enable = true;

    services.kanshi = {
      enable = true;
      systemdTarget = "hyprland-session.target";

      profiles = {
        undocked = {
          outputs = [
            {
              criteria = "eDP-1";
              scale = 1.1;
              status = "enable";
            }
          ];
        };

        docked = {
          outputs = [
            {
              criteria = "DP-1";
              position = "0,0";
              status = "enable";
            }
            {
              criteria = "eDP-1";
              status = "disable";
            }
          ];
        };
      };
    };

  services.vicinae = {
    enable = true;
    systemd = {
      enable = true;
      autoStart = true; # default: false
      environment = {
        USE_LAYER_SHELL = 1;
      };
    };
    settings = {
      close_on_focus_loss = true;
      consider_preedit = true;
      pop_to_root_on_close = true;
      favicon_service = "twenty";
      search_files_in_root = true;
      font = {
        normal = {
          size = 12;
          normal = "Maple Nerd Font";
        };
      };
      theme = {
        light = {
          name = "vicinae-light";
          icon_theme = "default";
        };
        dark = {
          name = "vicinae-dark";
          icon_theme = "default";
        };
      };
      launcher_window = {
        opacity = 0.98;
      };
    };
    extensions = with inputs.vicinae-extensions.packages.${pkgs.stdenv.hostPlatform.system}; [
      bluetooth
      nix
      power-profile
    ];
  };

  };
}
