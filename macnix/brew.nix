{ pkgs, ... }: {

  system.activationScripts.postUserActivation.text = ''
    # Install homebrew if it isn't there 
    if [[ ! -d "/opt/homebrew/bin" ]]; then
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    if [[ ! -d "/Users/killua/zgen" ]]; then
      git clone https://github.com/tarjoilija/zgen.git "${HOME}/.zgen"
    fi

    if [[ ! -f "/Users/killua/antigen.zsh" ]]; then
        curl -L git.io/antigen-nightly > /Users/killua/antigen.zsh
    fi
    if [[ ! -f "/Users/killua/.iterm2_shell_integration.zsh" ]]; then
        curl -L https://iterm2.com/shell_integration/install_shell_integration.sh | bash
    fi
  '';
  homebrew = {
    brewPrefix = "/opt/homebrew/bin";
    enable = true;
    autoUpdate = false;
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
          brew "antigen"
          brew "mpv"
          brew "php"
          brew "tree-sitter"
          brew "lazygit"
          lua-language-server luarocks pyright 

    '';
  };
}
