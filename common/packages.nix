
{ config, lib, pkgs, ... }:
{
      home.packages = with pkgs; [
          neovim-nightly
           (pkgs.nerdfonts.override { fonts = [ "JetBrainsMono"  ]; })     
           tmux
	   ripgrep
	   skim
      ];
}
