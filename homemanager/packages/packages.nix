{ pkgs, config, inputs, ... }:
{
  imports = [
    ./shell/zsh
    ./picom.nix
#    ./nvim.nix
     ./tmux.nix
  ];
}
