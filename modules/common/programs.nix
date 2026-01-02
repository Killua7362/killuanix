{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  userConfig = inputs.self.commonModules.user.userConfig;
in {
  config = {
    # Home Manager configuration
    programs.home-manager.enable = true;

    # Git configuration
    programs.git = {
      enable = true;
      userEmail = userConfig.email;
      userName = userConfig.fullName;
    };

    # Direnv configuration
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    # Zsh configuration (if using Zsh)
    programs.zsh = {
      enable = lib.mkDefault false;
      # Add common Zsh configuration here
    };

    # Fish configuration (if using Fish)
    programs.fish = {
      enable = lib.mkDefault false;
      # Add common Fish configuration here
    };

    # Starship configuration
    programs.starship = {
      enable = lib.mkDefault true;
      # Add common Starship configuration here
    };

    programs.dankMaterialShell = {
      enable = lib.mkDefault (pkgs.stdenv.isLinux);
    };

    # Platform-specific program configurations
    # programs.kitty = {
    #   enable = lib.mkDefault (pkgs.stdenv.isLinux);
    #   # Add Kitty configuration here
    # };

    # Linux-specific programs
    services.lorri.enable = lib.mkIf (pkgs.stdenv.isLinux) true;
    services.flatpak.enable = lib.mkIf (pkgs.stdenv.isLinux) true;

    # Additional program configurations can be added here
    # For example:
    # programs.tmux.enable = true;
    # programs.bat.enable = true;
    # programs.exa.enable = true;
  };
}
