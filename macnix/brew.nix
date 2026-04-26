# Homebrew is bootstrapped manually now (see root CLAUDE.md "Post-install
# setup"). We no longer auto-fetch homebrew/zgenom/antigen/miniconda from
# the internet via system.activationScripts.postUserActivation — those side
# effects were non-declarative and ran on every switch.
{pkgs, ...}: {
  homebrew = {
    brewPrefix = "/opt/homebrew/bin";
    enable = true;
    onActivation = {
      cleanup = "none";
      autoUpdate = false;
      upgrade = false;
    };
    global = {
      brewfile = true;
      lockfiles = true;
    };

    # Mac App Store apps. Populate from existing installs with `mas list`
    # — each line gives "<bundle id> <name>". Example:
    #   "Xcode" = 497799835;
    #   "Things 3" = 904280696;
    masApps = {
    };
    taps = [
      "FelixKratz/formulae"
      "homebrew/core"
      "mongodb/brew"
      "homebrew/cask"
      "dart-lang/dart"
      "yqrashawn/goku"
      "khanhas/tap"
      "candid82/brew"
      "homebrew/services"
      "ms-jpq/sad"
      # Removed taps:
      #   josephpage/jetpack-io  — unused
      #   oven-sh/bun            — bun now via nixpkgs (macPackages)
      #   zegervdv/zathura       — zathura not used on macnix
      #   homebrew/cask-versions — unused
      #   homebrew/cask-fonts    — fonts come from nixpkgs (macPackages)
      #   koekeishiya/formulae   — yabai/skhd dropped for AeroSpace
    ];
    # Casks. GUI apps live here when there's no good Mac story for them via
    # nixpkgs (most of them — nix-darwin builds CLI tools cleanly but GUI
    # bundles are easier through brew). The "desktop equivalent" comment
    # next to several entries flags packages that are in
    # modules/common/packages.nix → desktopPackages on Linux.
    casks = [
      # Existing toolkit
      "gitkraken"
      "gitkraken-cli"
      "macforge"
      "vimr"
      "ghostty"
      "shortcat"
      "wezterm"
      "raycast"
      # aerospace removed — installed declaratively via services.aerospace
      "renpy"
      "flameshot"
      "hiddenbar"
      "libreoffice" # desktop equivalent: libreoffice-qt6-fresh
      "quitter"
      "betterdummy"
      "itsycal"
      "next"
      "alt-tab"
      "raindropio"
      "browserosaurus"
      "hammerspoon"
      "glance"
      "hazeover"
      "marta"
      # karabiner-elements removed — installed declaratively via services.karabiner-elements
      "kawa"
      "imageoptim"
      "maccy"
      "kodi"
      "onyx"
      "qlmarkdown"
      "qlvideo"
      "spotify"
      "openemu"
      "vlc"
      "ticktick"
      "sublime-text" # desktop equivalent: sublime4

      # ── Mac equivalents of desktopPackages (Linux-only nixpkgs) ──
      "google-chrome" # desktop equivalent: google-chrome
      "qbittorrent" # desktop equivalent: qbittorrent
      "vscodium" # desktop equivalent: vscodium
      "postman" # desktop equivalent: postman
      "balenaetcher" # desktop equivalent: unetbootin (USB writer)
      "iina" # native macOS mpv front-end (mpv CLI also via nix macPackages)
      # NOTE: skim PDF viewer cask intentionally NOT listed — pkgs.skim in
      # macPackages is the fuzzy finder (different tool, same name). If you
      # want the PDF viewer, install it via Mac App Store or add it here.
      # NOTE: fonts come from nix-darwin / home-manager via
      # nerd-fonts.{jetbrains-mono,fira-code} in macPackages — not casks.
    ];
    # extraConfig: Brewfile lines for formulas that *aren't* a clean fit
    # for nixpkgs on darwin. Anything dropped from the previous list moved
    # into modules/common/packages.nix (commonPackages, terminalPackages,
    # devPackages, or the new macPackages additions), or comes through a
    # cross-platform program module (neovim, lazygit, yazi, git, …).
    #
    # Kept here because the brew build is more reliable / mac-native:
    #   - handbrake          GUI bundle, brew is canonical
    #   - choose-gui         macOS-only TUI menu
    #   - dart               nix darwin build is flaky
    #   - rust               brew tracks stable rustc closely; switch to
    #                        rustup-init via nix if you want
    #   - ldid               iOS code-signing tool, brew is canonical
    #   - python-tk          Tk binding for Homebrew python (required by
    #                        some scientific Python packages)
    #   - mongodb-community  needs `brew services` to start the daemon
    #   - asdf, antidote, zplug
    #                        shell plugin/runtime managers — they want to
    #                        manage their own state in $HOME, not the nix
    #                        store
    #   - sesh, devbox       fast-moving CLIs, brew formula is upstream
    #   - sad (ms-jpq)       custom tap, not in nixpkgs
    #   - goku               karabiner DSL compiler, custom tap
    #   - webarchiver, wallpaper, neovim-remote, cheat, rename
    #                        small utilities only packaged in brew
    #   - google-authenticator-libpam
    #                        PAM module, must live in /opt for sshd
    #   - jupyterlab         brew bundles the GUI launcher; nix has it too
    #                        but mixing macPackages.jupyter + brew sometimes
    #                        causes kernel discovery issues, so we prefer brew
    extraConfig = ''
      brew "handbrake"
      brew "choose-gui"
      brew "spicetify-cli"
      brew "webarchiver"
      brew "dart"
      brew "rust"
      brew "ldid"
      brew "zplug"
      brew "python-tk"
      brew "antidote"
      brew "wallpaper"
      brew "yqrashawn/goku/goku", restart_service: true
      brew "mas"
      brew "jupyterlab"
      brew "mongodb-community"
      brew "ms-jpq/sad/sad"
      brew "rename"
      brew "neovim-remote"
      brew "cheat"
      brew "google-authenticator-libpam"
      brew "asdf", args: ["HEAD"]
      brew "joshmedeski/sesh/sesh"
      brew "devbox"
    '';
  };
}
# Removed from extraConfig (now provided via nix on darwin):
#   git, fd, fzf, jq, bat, ripgrep, tree, sk, gh, less, zoxide, git-delta
#     → modules/common/packages.nix → commonPackages / terminalPackages
#   neovim, lazygit, yazi, tree-sitter, lua-language-server, stylua, prettier,
#   pyright, luarocks
#     → cross-platform programs modules (editors/neovim, dev/lazygit, utils/yazi)
#   ffmpeg, imagemagick, mpv, ranger, gnu-sed, thefuck, bun, pnpm, maven, php,
#   noti, trash, scrcpy, geckodriver, uutils-coreutils, dwm, youtube-dl
#     → modules/common/packages.nix → macPackages (added)
#
# Removed casks: nikitabobko/tap/aerospace, karabiner-elements
#   → installed declaratively via services.aerospace and
#     services.karabiner-elements in macnix/services.nix.
# Old historical comments preserved for reference:
#   docker-compose, ollama, zathura, skhd, yabai, anime-downloader, antigen,
#   sketchybar, tmux — none active.

