{ pkgs, ... }: {

  system.activationScripts.postUserActivation.text = ''
	#install cheatsheet globally
    if [[ ! -f "/usr/local/bin/cheat.sh" ]]; then
	    curl -s https://cht.sh/:cht.sh | sudo tee /usr/local/bin/cheat.sh && sudo chmod +x /usr/local/bin/cheat.sh
    fi

    # Install homebrew if it isn't there 
    if [[ ! -d "/opt/homebrew/bin" ]]; then
      arch -arm64 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    if [[ ! -f "/usr/local/bin/brew" ]]; then
      arch -x86_64 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    if [[ ! -d "/Users/killua/.zgenom" ]]; then
      git clone https://github.com/jandamm/zgenom.git "/Users/killua/.zgenom"
    fi

    if [[ ! -f "/Users/killua/antigen.zsh" ]]; then
        curl -L git.io/antigen-nightly > /Users/killua/antigen.zsh
    fi
    if [[ ! -f "/Users/killua/.iterm2_shell_integration.zsh" ]]; then
        curl -L https://iterm2.com/shell_integration/install_shell_integration.sh | bash
    fi
    if [[ ! -d "/Users/killua/miniconda3" ]]; then
	wget https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-arm64.sh
	sh Miniconda3-latest-MacOSX-arm64
	rm Miniconda3-latest-MacOSX-arm64
    fi
    if [[ ! -d "/Users/killua/miniconda3-intel" ]]; then
	wget https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-x86_64.sh
	sh Miniconda3-latest-MacOSX-x86_64
	rm Miniconda3-latest-MacOSX-x86_64
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
      "dart-lang/dart"
      "yqrashawn/goku"
      

    ];
    casks = [
    "hiddenbar"
    "next"
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
          brew "koekeishiya/formulae/skhd",restart_service:true
          brew "koekeishiya/formulae/yabai",restart_service:true
          brew "antigen"
          brew "dart"
          brew "mpv"
          brew "php"
          brew "tree-sitter"
          brew "lazygit"
          brew "lua-language-server"
            brew "luarocks"
          brew "pyright"
	  brew "dmenu-mac"
	  brew "jq"
	  brew "noti"
	  brew "ranger"
	  brew "yqrashawn/goku/goku",restart_service:true
    '';
  };
}
