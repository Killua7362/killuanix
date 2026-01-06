{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:  let
     userConfig = inputs.self.commonModules.user.userConfig;
     dotfilesPath = "${config.home.homeDirectory}/killuanix/DotFiles";
   in
{
  imports = [
    ../common/programs/kitty.nix
    ../common/programs/git.nix
    ../common/programs/fish.nix
    ../common/programs/dots.nix
    ../common/programs/hyprland
    ../common/programs/neovim
    ../common/programs/firefox
  ];

  config = {

    # Home Manager configuration
    programs.home-manager.enable = true;

    programs.less.enable = true;

    # Direnv configuration
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };


    # Starship configuration
    programs.starship = {
      enable = lib.mkDefault true;
      enableFishIntegration = true;
    };

    xdg.configFile."starship.toml".source = "${dotfilesPath}/starship.toml";

    programs.nix-index.enable = true;
    programs.nix-index-database.comma.enable = true;
  };
}
