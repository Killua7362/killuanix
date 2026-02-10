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
    ../common/programs/zsh.nix
    ../common/programs/dots.nix
    ../common/programs/hyprland
    ../common/programs/neovim
    ../common/programs/firefox
    ../common/programs/lazygit.nix
    ../common/programs/starship.nix
    ../common/programs/zellij.nix
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

    programs.nix-index.enable = true;
    programs.nix-index-database.comma.enable = true;
  };
}
