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
    ../common/sops.nix
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
    home.packages =
      commonPackages
      ++ terminalPackages
      ++ devPackages
      ++ (
        if pkgs.stdenv.isLinux
        then desktopPackages
        else []
      )
      ++ (
        if pkgs.stdenv.isDarwin
        then macPackages
        else []
      );

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
          LD_LIBRARY_PATH = lib.mkDefault "/usr/lib/pipewire-0.3/jack";
          # XDG_CONFIG_HOME = "$HOME/.config";
          # XDG_DATA_DIRS = "$HOME/.nix-profile/share:$XDG_DATA_DIRS";
        }
        else if pkgs.stdenv.isDarwin
        then {
          TERMINFO_DIRS = "${pkgs.kitty.terminfo.outPath}/share/terminfo";
        }
        else {}
      );

    # home.sessionVariablesExtra = ''
    #   export XDG_DATA_DIRS="$HOME/.local/share''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
    # '';

    # Platform-specific services
    services.lorri.enable = lib.mkIf (pkgs.stdenv.isLinux) true;
    services.flatpak.enable = lib.mkIf (pkgs.stdenv.isLinux) true;

    # targets.genericLinux.enable = lib.mkIf (pkgs.stdenv.isLinux) true;

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
      "org.jdownloader.JDownloader"
    ];

    # Pre-seed JDownloader2 flatpak config (download path, disable auto-updates, Real-Debrid)
    home.activation.jdownloaderConfig = lib.mkIf (pkgs.stdenv.isLinux) (lib.hm.dag.entryAfter ["writeBoundary" "sopsNix"] (let
      jdCfgDir = "${config.home.homeDirectory}/.var/app/org.jdownloader.JDownloader/data/jdownloader/cfg";
      generalSettings = builtins.toJSON {
        defaultdownloadfolder = "${config.home.homeDirectory}/Downloads/JDownloader";
      };
      updateSettings = builtins.toJSON {
        autoupdateenabled = false;
        autoinstallupdatesenabled = false;
        installupdatesonexitenabled = false;
        donotaskagainselectedbyuser = true;
      };
      realdebridSecret = config.sops.secrets."realdebrid_token".path;
    in ''
            mkdir -p "${jdCfgDir}"

            # Download path
            if [ ! -f "${jdCfgDir}/org.jdownloader.settings.GeneralSettings.json" ]; then
              cat > "${jdCfgDir}/org.jdownloader.settings.GeneralSettings.json" <<'JSONEOF'
      ${generalSettings}
      JSONEOF
            fi

            # Disable auto-updates
            if [ ! -f "${jdCfgDir}/org.jdownloader.update.UpdateSettings.json" ]; then
              cat > "${jdCfgDir}/org.jdownloader.update.UpdateSettings.json" <<'JSONEOF'
      ${updateSettings}
      JSONEOF
            fi

            # Real-Debrid API token from sops
            if [ -f "${realdebridSecret}" ] && [ ! -f "${jdCfgDir}/org.jdownloader.plugins.components.RealDebridCom.json" ]; then
              RD_TOKEN=$(cat "${realdebridSecret}")
              cat > "${jdCfgDir}/org.jdownloader.plugins.components.RealDebridCom.json" <<JSONEOF
      {"apitoken":"$RD_TOKEN"}
      JSONEOF
            fi
    ''));

    # services.kdeconnect.enable = true;

    services.kanshi = {
      enable = false;
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
        {
          profile.name = "office";
          profile.outputs = [
            {
              criteria = "HDMI-A-1";
              status = "enable";
            }
            {
              criteria = "eDP-1";
              status = "enable";
            }
          ];
        }
      ];
    };

    fonts.fontconfig.enable = true;
    home.pointerCursor = {
      gtk.enable = true;
      # x11.enable = true;
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 16;
    };
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

    dconf.settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        gtk-theme = "adw-gtk3-dark";
        icon-theme = "Adwaita";
        cursor-theme = "Adwaita";
        font-name = "JetBrainsMono Nerd Font 11";
      };
    };
    xdg.configFile."uwsm/env".source = "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";
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
        providers = {
          applications = {
            launchPrefix = "uwsm app --";
            defaultAction = "focus";
          };
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
      components = ["secrets" "pkcs11"];
    };
  };
}
