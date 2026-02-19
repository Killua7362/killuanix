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
  ];

  config = {
    # Common system settings
    xdg.enable = true;
    xdg.mime.enable = true;

    # Platform-specific configurations
    nixpkgs.config.allowUnfree = true;

    nixpkgs.config.permittedInsecurePackages = [
        "openssl-1.1.1w"
    ];

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

    # targets.genericLinux.enable = lib.mkIf (pkgs.stdenv.isLinux) true;
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
      "us.zoom.Zoom"
    ];

    services.kdeconnect.enable = true;

    services.kanshi = {
      enable = true;
      systemdTarget = "";

      settings = [
        {
            profile.name = "undocked";
            profile.outputs = [
              {
                criteria = "eDP-1";
                scale = 1.1;
                status = "enable";
              }
            ];
          }
          {
              profile.name = "docked";
              profile.outputs = [

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
          }
      ];
    };

  fonts.fontconfig.enable = true;

    gtk = {
      enable = true;

      # adw-gtk3-dark gives GTK3 apps the modern libadwaita look
      theme = {
        name = "adw-gtk3-dark";
        package = pkgs.adw-gtk3;
      };

      iconTheme = {
        name = "Adwaita";
        package = pkgs.adwaita-icon-theme;
      };

      cursorTheme = {
        name = "Adwaita";
        package = pkgs.adwaita-icon-theme;
        size = 24;
      };

      font = {
        name = "JetBrainsMono Nerd Font";
        size = 11;
      };

      gtk3.extraConfig = {
        gtk-application-prefer-dark-theme = 1;
        gtk-theme-name = "adw-gtk3-dark";
      };

      gtk4.extraConfig = {
        gtk-application-prefer-dark-theme = true;
      };
    };

    qt = {
      enable = true;
      platformTheme.name = "adwaita";
      style = {
        name = "adwaita-dark";
        package = pkgs.adwaita-qt;
      };
    };

    # xdg.portal = {
    #   enable = true;
    #   extraPortals = with pkgs; [
    #     xdg-desktop-portal-hyprland
    #     xdg-desktop-portal-gtk
    #   ];
    #
    #   configPackages = [ config.wayland.windowManager.hyprland.package ];
    #
    #   config.hyprland = {
    #     default = [ "hyprland" "gtk" ];
    #     "org.freedesktop.impl.portal.FileChooser" = "gtk";
    #     "org.freedesktop.impl.portal.Print" = "gtk";
    #   };
    #
    # };

    dconf.settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        gtk-theme = "adw-gtk3-dark";
        icon-theme = "Adwaita";
        cursor-theme = "Adwaita";
        font-name = "JetBrainsMono Nerd Font 11";
      };
    };

chaotic.nyx = {
  cache.enable = true;
};
  services.vicinae = {
    enable = true;
    systemd = {
      enable = true;
      autoStart = true;
      environment = {
        USE_LAYER_SHELL = 1;
      };
    };
    settings = {
      close_on_focus_loss = false;
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
        name = "vicinae-dark";
        light = {
          name = "vicinae-light";
          icon_theme = "default";
        };
        dark = {
          name = "vicinae-dark";
          icon_theme = "default";
        };
      };
      keybinding = "emacs";
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

  services.gnome-keyring = {
    enable = true;
    components = [ "secrets" "pkcs11" ];
  };

  };
}
