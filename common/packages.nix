{ config, lib, pkgs, ... }:
{
  home.packages = with pkgs; [
    #neovim-nightly
    pkgs.nerd-fonts.jetbrains-mono
    #tmux
    ripgrep
    skim
  ];
}
