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
      bat
      chafa
      exiftool
      lesspipe

      # Development tools
      git
      nix-search-cli
      nixpkgs-fmt
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
      eza
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
      nerd-fonts.jetbrains-mono
      # Adwaita theming
      adw-gtk3              # Modern Adwaita look for GTK3 apps
      adwaita-icon-theme    # Icons and cursors
      gnome-themes-extra    # Extra Adwaita assets (optional, for full coverage)

      # QT Adwaita integration
      adwaita-qt            # Qt5 Adwaita style
      adwaita-qt6           # Qt6 Adwaita style
      gnome-keyring
      libsecret
      seahorse
      nixgl.nixVulkanIntel
      grim
      slurp
      wl-clipboard
      cliphist
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
