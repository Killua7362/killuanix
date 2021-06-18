{ pkgs, config, inputs, libs, ... }:
{
  home.username = "killua";
  home.homeDirectory = "/home/killua";
  programs.home-manager.enable = true;
  programs.home-manager.path = https://github.com/nix-community/home-manager/archive/master.tar.gz;

  imports = [
    ./packages/packages.nix
    ./users/dots-manage.nix
    ./users/theme.nix
    ./users/commands.nix
#    ./users/proton.nix
    ./users/alacritty.nix
  ];
  home.packages = with pkgs; [
  adapta-gtk-theme
luajitPackages.lua-lsp
nodePackages.bash-language-server
      tree-sitter
      neovim-remote
    adl
    kmonad
    brave
    pcmanfm
    unetbootin
   qbittorrent
    sublime3
    hakuneko
    ffmpegthumbnailer
    terminator
    fontpreview
    mach-nix
    okular
    anime-downloader
    appimage-run
    appimagekit
    arandr
    betterdiscordctl
    bottom
    cachix
    gzip
    comma
    discord-canary
    flameshot
    git-crypt
    lazygit
    luarocks-nix
    mpv
    neofetch
    nitrogen
    nix-prefetch-github
    nix-script
    nixpkgs-fmt
    numix-gtk-theme
    numix-icon-theme-circle
    papirus-icon-theme
    rnix-lsp
    starship
    trackma
    unar
    update-nix-fetchgit
    vscodium
    xarchiver
    xkb-switch
    xorg.xhost
    yarn
    yarn2nix
    zathura
    file
  ];

  home.file."/home/killua/.config/pacmanfile/pacmanfile-1.txt".text = ''
    bat
    wezterm
    awesome-git
    firefox-nightly
    sddm
    ntfs-3g
    networkmanager
    nano
    nvidia-dkms
    nvidia-settings
    nvidia-utils
    optimus-manager
    optimus-manager-qt
    pavucontrol
    pulseaudio
    vivaldi
    vivaldi-widevine
    woeusb-ng
    gnome-disk-utility
    git
    adapta-gtk-theme
    papirus-icon-theme
    network-manager-applet
   '';

  services.lorri.enable = true;
  programs.git = {
    enable = true;
    userEmail = "bhat7362@gmail.com";
    userName = "Killua7362";
  };
  xdg.enable = true;
  xdg.mime.enable = true;
  targets.genericLinux.enable = true;

  home.activation = {
    pacmanfile = ''
  bash ~/archnix/scripts/pacmanfile/pacmanfile dump    
  bash ~/archnix/scripts/pacmanfile/pacmanfile sync --noconfirm
    '';
  
paru = ''
    bash ~/archnix/scripts/paru
'';
  
};
systemd.user.startServices = true;
systemd.user.systemctlPath = "/bin/systemctl";
}
