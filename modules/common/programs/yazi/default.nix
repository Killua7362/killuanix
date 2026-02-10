{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:{
  programs.yazi = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        yazi = lib.importTOML ./settings.toml;
        keymap = lib.importTOML ./keymap.toml;
        theme = lib.importTOML ./theme.toml;      
      };
      flavors = {
        inherit (pkgs.yaziFlavors)
        vscode-dark-plus;
      };
      plugins = {
        inherit (pkgs.yaziPlugins) mount;
      };
  };

  # programs.yazi.yaziPlugins = {
  #   enable = true;
  #   plugins = {
  #     starship.enable = true;
  #     jump-to-char = {
  #       enable = true;
  #       keys.toggle.on = [ "F" ];
  #     };
  #     relative-motions = {
  #       enable = true;
  #       show_numbers = "relative_absolute";
  #       show_motion = true;
  #     };
  #   };
  # };

}
