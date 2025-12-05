{ pkgs, config, inputs,nixgl, libs, ... }:
{
  programs.home-manager.enable = true;
  #programs.home-manager.path = https://github.com/nix-community/home-manager/archive/master.tar.gz;

  imports = [
    ./users/dots-manage.nix
    ./users/theme.nix
    ./users/commands.nix
    ./users/appimages.nix
  ];

  myAppImages = {
    enable = true;

    apps = {
      "PrismLauncher" = {
        repoOwner = "Diegiwg";
        repoName = "PrismLauncher-Cracked";
        releaseTag = "9.4";
        fileName = "PrismLauncher-Linux-x86_64.AppImage";
      };
      "Anymex" = {
        repoOwner = "RyanYuuki";
        repoName = "AnymeX";
        releaseTag = "v3.0.1";
        fileName = "AnymeX-Linux.AppImage";
      };
    };
  };

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

  services.flatpak = {
    enable = true;
    packages = [
        "com.logseq.Logseq"
        "com.github.tchx84.Flatseal"
        "com.usebottles.bottles"
        "io.missioncenter.MissionCenter"
        "io.github.limo_app.limo"
        "io.github.fastrizwaan.WineZGUI"
        "com.jetbrains.CLion"
        "org.vinegarhq.Sober"
        "io.github.nozwock.Packet"
      ];
  };
}
