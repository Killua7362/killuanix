{ config, pkgs, lib, inputs, ... }:

let
  userConfig = inputs.self.commonModules.user.userConfig;
  commonPackages = inputs.self.commonModules.packages.commonPackages pkgs;
  terminalPackages = inputs.self.commonModules.packages.terminalPackages pkgs;
  desktopPackages = inputs.self.commonModules.packages.desktopPackages pkgs;
  devPackages = inputs.self.commonModules.packages.devPackages pkgs;
  macPackages = inputs.self.commonModules.packages.macPackages pkgs;
in
{
  config = {
    # Common home-manager configuration
    programs.home-manager.enable = true;

    # Common system settings
    xdg.enable = true;
    xdg.mime.enable = true;

    # Common git configuration
    programs.git = {
      enable = true;
      userEmail = userConfig.email;
      userName = userConfig.fullName;
    };

    # Common direnv configuration
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    # Platform-specific configurations
    nixpkgs.config.allowUnfree = true;

    # Common packages - these will be available on all systems
    home.packages = commonPackages ++ terminalPackages ++ devPackages;

    # Platform-specific package additions
    # home.packages = lib.mkIf (pkgs.stdenv.isLinux) (desktopPackages ++ [
    #   inputs.neovim-nightly-overlay.packages.${pkgs.system}.default
    # ]);
    #
    # home.packages = lib.mkIf (pkgs.stdenv.isDarwin) macPackages;

    # Platform-specific home directory
    home.username = userConfig.username;
    home.homeDirectory =
      if pkgs.stdenv.isLinux then userConfig.homeDirectories.linux
      else if pkgs.stdenv.isDarwin then userConfig.homeDirectories.mac
      else "/home/${userConfig.username}";

    # Platform-specific session variables
    home.sessionVariables = userConfig.sessionVariables // (
      if pkgs.stdenv.isLinux then {
        MANPAGER = "nvim +Man!";
        MANWIDTH = "999";
        KEYTIMEOUT = "1";
        LG_CONFIG_FILE = "$HOME/.config/lazygit.yml";
        # XDG_CONFIG_HOME = "$HOME/.config";
        # XDG_DATA_DIRS = "$HOME/.nix-profile/share:$XDG_DATA_DIRS";
      } else if pkgs.stdenv.isDarwin then {
        TERMINFO_DIRS = "${pkgs.kitty.terminfo.outPath}/share/terminfo";
      } else {}
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
  };
}
