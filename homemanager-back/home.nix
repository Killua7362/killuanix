{ pkgs, ... }: {

  home.packages = with pkgs;[
    brave
    neovim-nightly
    nixpkgs-fmt
adl
  ];
  xdg.enable = true;
  xdg.mime.enable = true;
  targets.genericLinux.enable = true;

}
