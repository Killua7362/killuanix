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
      fastfetch
      cachix
      git-crypt
      nix-prefetch-github
      nix-script
      update-nix-fetchgit
      nodejs_20
      tree-sitter
      sops
      age
      ssh-to-age
    ])
    ++ [
      (import ../../packages/claude-monitor/package.nix {
        inherit pkgs;
        inherit (pkgs) lib;
        inherit (inputs) uv2nix pyproject-nix pyproject-build-systems;
      })
    ];

  # Terminal and shell packages
  terminalPackages = pkgs:
    with pkgs; [
      delta
      zplug
      eza
      proxychains-ng
      (writeShellApplication {
        name = "ns";
        runtimeInputs = with pkgs; [
          fzf
          nix-search-tv
        ];
        text = builtins.readFile "${pkgs.nix-search-tv.src}/nixpkgs.sh";
      })
      (callPackage ./programs/openchamber/default.nix {})
    ];

  # Desktop packages (Linux specific)
  desktopPackages = pkgs:
    with pkgs; [
      # pcmanfm — replaced by nemo (configured in utils/nemo.nix)
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
      adw-gtk3 # Modern Adwaita look for GTK3 apps
      adwaita-icon-theme # Icons and cursors
      gnome-themes-extra # Extra Adwaita assets (optional, for full coverage)

      # QT Adwaita integration
      adwaita-qt # Qt5 Adwaita style
      adwaita-qt6 # Qt6 Adwaita style
      gnome-keyring
      libsecret
      seahorse
      grim
      slurp
      wl-clipboard
      cliphist
      libreoffice-qt6-fresh
      nwg-displays
      sublime4
      loupe
      mpv
      papers
    ];

  # Development packages
  devPackages = pkgs:
    with pkgs; [
      luarocks-nix
      trackma
    ];

  # Mac-specific packages.
  #
  # These are the darwin counterparts to desktopPackages/devPackages — every
  # entry here is something that builds for aarch64-darwin via nixpkgs.
  # Anything strictly Linux-only (Wayland tools, GTK theming, NetworkManager,
  # gnome-keyring, X11 utilities, etc.) is dropped because macOS ships
  # native equivalents (Keychain, Preview, System Settings, AppleScript).
  # Anything that's only available as a GUI cask on Mac (postman,
  # qbittorrent, vscodium, google-chrome, IINA, …) is in
  # macnix/brew.nix → homebrew.casks instead.
  macPackages = pkgs:
    with pkgs; [
      # already-mac-specific
      skim
      antigen
      cht-sh

      # CLI media / image / format tools (used to be brew-only)
      mpv
      ffmpeg
      imagemagick
      yt-dlp # replaces brew "youtube-dl"

      # Shell / terminal niceties
      gnused # GNU sed alongside macOS BSD sed
      thefuck
      ranger
      noti
      trash-cli # replaces brew "trash"
      uutils-coreutils

      # Languages / package managers that build cleanly on darwin
      bun
      pnpm
      maven
      php

      # Dev tooling
      tree-sitter
      prettier
      pyright
      jupyter

      # Misc
      mas # Mac App Store CLI (also kept via brew for redundancy)
      scrcpy
      geckodriver

      # Fonts (NixOS uses fonts.packages on the system; on darwin Home Manager
      # writes them under ~/Library/Fonts via fonts.fontconfig)
      nerd-fonts.jetbrains-mono
      nerd-fonts.fira-code
    ];
}
