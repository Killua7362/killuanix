{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  userConfig = inputs.self.commonModules.user.userConfig;
  dotfilesPath = "${config.home.homeDirectory}/killuanix/DotFiles";
in {
  imports = [
    ../common/programs/shells
    ../common/programs/terminal
    ../common/programs/editors
    ../common/programs/browsers
    ../common/programs/dev
    ../common/programs/desktop
    ../common/programs/audio
    ../common/programs/media
    ../common/programs/utils
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
