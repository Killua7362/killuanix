{ pkgs, config, inputs, libs, ... }:
{
  home.username = "killua";
  home.homeDirectory = "/home/killua";
  programs.home-manager.enable = true;
  #programs.home-manager.path = https://github.com/nix-community/home-manager/archive/master.tar.gz;

  imports = [
    ./users/dots-manage.nix
    ./users/theme.nix
    ./users/commands.nix
  ];

  home.packages = with pkgs; [
    pcmanfm
    unetbootin
    qbittorrent
    sublime3
    hakuneko
    fontpreview
    okular
    arandr
    bottom
    cachix
    comma
    flameshot
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
    neovim
    fd
    tmux
    delta
    zplug
    direnv
    thefuck
    zoxide
    eza
    fzf
  ];

  services.lorri.enable = true;

  xdg.enable = true;
  xdg.mime.enable = true;
  targets.genericLinux.enable = true;
  systemd.user.startServices = true;
  systemd.user.systemctlPath = "/bin/systemctl";
}
