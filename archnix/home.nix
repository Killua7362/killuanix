{ pkgs, config, inputs,nixgl, libs, ... }:
{
  programs.home-manager.enable = true;
  #programs.home-manager.path = https://github.com/nix-community/home-manager/archive/master.tar.gz;

  imports = [
    ./users/dots-manage.nix
    ./users/theme.nix
    ./users/commands.nix
  ];
# i18n.inputMethod = {
#   enable = true;
#   type = "fcitx5";
#   fcitx5.addons = with pkgs; [ fcitx5-mozc fcitx5-gtk ];
# };
  home.packages = with pkgs; [
    inputs.neovim-nightly-overlay.packages.${pkgs.system}.default
    pcmanfm
    unetbootin
    qbittorrent
    hakuneko
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
    foot
  ];

  services.lorri.enable = true;

  xdg.enable = true;
  xdg.mime.enable = true;
  targets.genericLinux.enable = true;
  systemd.user.startServices = true;
  systemd.user.systemctlPath = "/bin/systemctl";
}
