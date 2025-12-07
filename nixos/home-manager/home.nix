{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {

  imports = builtins.attrValues inputs.self.homeManagerModules ++ [
    ./users/dots-manage.nix
  ];

  nixpkgs = {
    overlays = [
       inputs.neovim-nightly-overlay.overlays.default
    ];
    config = {
      allowUnfree = true;
    };
  };
  home = {
    username = "killua";
    homeDirectory = "/home/killua";
  };

  home.packages = with pkgs; [
    jetbrains.idea-ultimate
    qbittorrent
    fontpreview
    arandr
    bottom
    cachix
    comma
    git-crypt
    lazygit
    luarocks-nix
    neofetch
    nitrogen
    nix-prefetch-github
    nix-script
    nixpkgs-fmt
    starship
    trackma
    update-nix-fetchgit
    vscodium
    zathura
    file
    dmenu
    fd
    tmux
    delta
    zplug
    direnv
    zoxide
    eza
    fzf
    nix-search-cli
  ];

  programs.home-manager.enable = true;
  programs.git.enable = true;

  systemd.user.startServices = "sd-switch";

  home.stateVersion = "25.11";
}
