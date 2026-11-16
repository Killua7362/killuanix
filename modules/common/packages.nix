{
  # Common packages that are useful across all systems
  commonPackages = pkgs: inputs:
    (with pkgs; [
      # File utilities
      fd
      ripgrep # real `rg` binary — rtk's `rg`/search subcommand shells out to it (shell `rg` is a Claude Code function, invisible to subprocesses)
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
      nh # nix-helper: faster rebuilds + closure diff (wired into nix_switch)
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
      nodejs_22
      tree-sitter
      sops
      age
      ssh-to-age
      jq
      openssl
      zip
      unzip
    ])
    ++ [
      (import ../../packages/claude-monitor/package.nix {
        inherit pkgs;
        inherit (pkgs) lib;
        inherit (inputs) uv2nix pyproject-nix pyproject-build-systems;
      })
      inputs.ghgrab.packages.${pkgs.stdenv.hostPlatform.system}.default
      # RTK (Rust Token Killer): compresses verbose dev-command output before
      # it reaches Claude Code. Not in nixpkgs; built from the upstream git tag.
      (pkgs.callPackage ../../packages/rtk/package.nix {})
    ];

  # Terminal and shell packages
  terminalPackages = pkgs:
    with pkgs; [
      delta
      zplug
      eza
      proxychains-ng
      sshpass # non-interactive ssh password for `bastion` DB tunnels (DA_SSH_PASSWORD)
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
  desktopPackages = pkgs: inputs:
    with pkgs; [
      # pcmanfm — replaced by nemo (configured in utils/nemo.nix)
      unetbootin
      ventoy-full
      (writeShellApplication {
        name = "ventoy-gui";
        runtimeInputs = [ventoy-full];
        text = ''
          # Launch Ventoy local web UI (needs root for raw disk access).
          # Browser opens automatically at http://127.0.0.1:24680.
          exec sudo -E env PATH="$PATH" ventoy-web "$@"
        '';
      })
      qbittorrent
      # rssguard installed by modules/common/programs/rss (config + package travel together)
      hakuneko
      fontpreview
      arandr
      nwg-displays
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
      # Sublime Text 4 stable build 4215. nixpkgs still ships 4200 (the old
      # Python 3.3 plug-in host + EOL OpenSSL 1.1), so build the newer
      # release from nixpkgs' own sublime/4/common.nix — for >=4205 it wires
      # the Python 3.14 plug-in host against openssl_3_5, no insecure pkgs.
      # Bump buildVersion + hashes on upgrade; drop once nixpkgs catches up.
      ((pkgs.callPackage (import "${pkgs.path}/pkgs/applications/editors/sublime/4/common.nix" {
          buildVersion = "4215";
          x64sha256 = "wVP0GNOrJrkOzOjAKoLk6WECXtemX34lBgpUV9Q+iNk=";
          aarch64sha256 = "0xRmWkJy8zVRUDQyNyo0UW27WpoS3OKkcELBlC9m7nk=";
        }))
        {})
      loupe
      mpv
      papers
      vial
      dbeaver-bin # GUI DB client
      # DroidCam Linux client (phone-as-webcam/mic over USB-adb or Wi-Fi).
      # Provides `droidcam` (GTK GUI) + `droidcam-cli`. Needs the NixOS side
      # too: v4l2loopback (video sink) + snd-aloop (mic sink) kernel modules.
      droidcam
    ];

  # Development packages
  devPackages = pkgs:
    with pkgs; [
      luarocks-nix
      trackma
      postgresql # provides `psql` client (+ server bins, unused)
      sqlite # provides `sqlite3` CLI
    ];

  # Mac-specific packages
  macPackages = pkgs:
    with pkgs; [
      skim
      antigen
      cht-sh
    ];
}
