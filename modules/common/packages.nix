{
  # Common packages that are useful across all systems
  commonPackages = pkgs: inputs:
    (with pkgs; [
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
      git-crypt
      nix-prefetch-github
      nix-script
      update-nix-fetchgit
nodejs_20
      tree-sitter
    ]) ++ [
      inputs.opencode-flake.packages.${pkgs.system}.default
    ];

  # Terminal and shell packages
  terminalPackages = pkgs:
    with pkgs; [
      delta
      zplug
    ];

  # Desktop packages (Linux specific)
  desktopPackages = pkgs:
    with pkgs; [
      pcmanfm
      unetbootin
      qbittorrent
      hakuneko
      fontpreview
      arandr
      nitrogen
      vscodium
      dmenu
      foot
      gcr
      hyprpolkitagent
      networkmanagerapplet
      postman
      google-chrome
      teleport
    ];

  # Development packages
  devPackages = pkgs:
    with pkgs; [
      luarocks-nix
      trackma
    ];

  # Mac-specific packages
  macPackages = pkgs:
    with pkgs; [
      skim
      antigen
      cht-sh
    ];
}
