{ pkgs, ... }: {

  system.activationScripts.postUserActivation.text = ''
    # Install homebrew if it isn't there 
    if [[ ! -d "/opt/homebrew/bin" ]]; then
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    #install oh-my-zsh if not exist
    if [[ ! -d "/Users/killua/.oh-my-zsh" ]]; then
        /bin/bash -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    fi
  '';
  homebrew = {
    brewPrefix = "/opt/homebrew/bin";
    enable = true;
    autoUpdate = true;
    cleanup = "zap";
    global = {
      brewfile = true;
      noLock = true;
    };
    taps = [
      "homebrew/core"
      "homebrew/cask"
      "homebrew/cask-fonts"

    ];
    casks = [
      "alt-tab"
      "android-studio"
      "blender"
      "browserosaurus"
      "flameshot"
      "citra"
      "hammerspoon"
      "glance"
      "hazeover"
      "marta"
      "hyperdock"
      "karabiner-elements"
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
      "visual-studio-code"
      "ticktick"
      "sublime-text"
      "zotero"
    ];
    # REMOVED: brew "xorpse/formulae/yabai", args: ["HEAD"]
    extraConfig = ''
      brew "handbrake"
      brew "anime-downloader"
      brew "choose-gui"
          brew "git"

          brew "coreutils"
          brew "ffmpeg"
          brew "imagemagick"
          brew "khanhas/tap/spicetify-cli"
          brew "youtube-dl"
          brew "zegervdv/zathura/zathura"
          brew "zegervdv/zathura/zathura-pdf-mupdf"
          brew "webarchiver"
          brew "koekeishiya/formulae/skhd"
          brew "koekeishiya/formulae/yabai"
          brew "mpv"
          brew "php"
          brew "tree-sitter"
          brew "lazygit"

    '';
  };
}
