{ pkgs, ... }:

{
  # Common packages that are useful across all systems
  commonPackages = with pkgs; [
    # File utilities
    fd
    fzf
    eza
    file
    bottom

    # Development tools
    git
    lazygit
    nix-search-cli
    nixpkgs-fmt
    starship
    direnv
    zoxide

    # System utilities
    tldr
    neofetch
    cachix
    comma
    git-crypt
    nix-prefetch-github
    nix-script
    update-nix-fetchgit
  ];

  # Terminal and shell packages
  terminalPackages = with pkgs; [
    tmux
    delta
    zplug
  ];

  # Desktop packages (Linux specific)
  desktopPackages = with pkgs; [
    pcmanfm
    unetbootin
    qbittorrent
    hakuneko
    fontpreview
    arandr
    nitrogen
    vscodium
    zathura
    dmenu
    foot
  ];

  # Development packages
  devPackages = with pkgs; [
    luarocks-nix
    trackma
  ];

  # Mac-specific packages
  macPackages = with pkgs; [
    skim
    antigen
    prefmanager
    cht-sh
  ];
}