{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    ../modules/cross-platform
    ./dots-manage.nix
  ];

  # Mac-specific state version
  home.stateVersion = "24.05";

  # Mac-specific shell configuration
  programs.zsh.enable = true;
}
