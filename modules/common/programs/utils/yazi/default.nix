{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  # The pinned `pkgs.yaziFlavors.vscode-dark-plus` (jun-11) predates yazi's
  # schema change that renamed `name = …` to `url = …` in filetype/icon
  # rules. Patch the flavor.toml at build time so the current yazi accepts it.
  vscode-dark-plus-fixed = pkgs.runCommand "yazi-flavor-vscode-dark-plus-patched" {} ''
    cp -r ${pkgs.yaziFlavors.vscode-dark-plus} $out
    chmod -R u+w $out
    ${pkgs.gnused}/bin/sed -i 's/\bname = /url = /g' $out/flavor.toml
  '';
in {
  programs.yazi = {
    enable = true;
    shellWrapperName = "yy";
    enableZshIntegration = true;
    settings = lib.importTOML ./yazi.toml;
    keymap = lib.importTOML ./keymap.toml;
    theme = lib.importTOML ./theme.toml;
    package = inputs.yazi.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
      _7zz = pkgs._7zz-rar; # Support for RAR extraction
    };
    flavors = {
      vscode-dark-plus = vscode-dark-plus-fixed;
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
