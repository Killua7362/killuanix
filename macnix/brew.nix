{pkgs, ...}: {
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
    onActivation = {
      cleanup = "none";
      autoUpdate = false;
      upgrade = false;
    };
    global = {
      brewfile = true;
      lockfiles = true;
    };
    taps = [
      "josephpage/jetpack-io"
      "FelixKratz/formulae"
      "oven-sh/bun"
      "zegervdv/zathura"
      "homebrew/core"
      "mongodb/brew"
      "homebrew/cask"
      "homebrew/cask-fonts"
      "dart-lang/dart"
      "yqrashawn/goku"
      "khanhas/tap"
      "candid82/brew"
      "homebrew/cask-versions"
      "koekeishiya/formulae"
      "homebrew/services"
      "ms-jpq/sad"
    ];
    casks = [
      "gitkraken"
      "gitkraken-cli"
      "macforge"
      "vimr"
      "ghostty"
      "shortcat"
      "wezterm"
      "raycast"
      "nikitabobko/tap/aerospace"
      "renpy"
      "flameshot"
      #"docker"
      # "kitty"
      # "android-platform-tools"
      # "visual-studio-code"
      "hiddenbar"
      # "brave-browser"
      "libreoffice"
      "quitter"
      "betterdummy"
      # "lulu"
      "itsycal"
      "next"
      "alt-tab"
      "raindropio"
      # "android-studio"
      # "xquartz"
      # "blender"
      "browserosaurus"
      # "citra"
      "hammerspoon"
      "glance"
      "hazeover"
      "marta"
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
      "ticktick"
      "sublime-text"
      # "zotero"
    ];
    # REMOVED: brew "xorpse/formulae/yabai", args: ["HEAD"]
    extraConfig = ''
                                brew "handbrake"
                                brew "neovim",args:["HEAD"]
                                brew "choose-gui"
                                brew "git"
                                brew "ffmpeg"
                                brew "imagemagick"
                                brew "spicetify-cli"
                                brew "youtube-dl"
                                brew "webarchiver"
                                brew "dart"
                                brew "mpv"
                                brew "php"
                                brew "tree-sitter",args:["HEAD"]
                                brew "lazygit"
                                brew "lua-language-server"
                                brew "luarocks"
                                brew "pyright"
                                brew "jq"
                                brew "noti"
                                brew "rust"
                                brew "ldid"
                                brew "zplug"
                                brew "python-tk"
                                brew "antidote"
                                brew "yazi",args:["HEAD"]
                                brew "scrcpy"
                                brew "fzf"
                                brew "less"
                                brew "zoxide"
                                brew "rename"
                                brew "ranger"
                                brew "wallpaper"
                                brew "yqrashawn/goku/goku",restart_service:true
                                brew "mas"
                                brew "jupyterlab"
                                brew "dwm"
                                brew "stylua"
                                brew "prettier"
                                brew "mongodb-community"
                                brew "ms-jpq/sad/sad"
                                brew "git-delta"
                                brew "fd"
                                brew "geckodriver"
                                brew "maven"
                                brew "ripgrep"
                                brew "bun"
                                brew "gnu-sed"
                                brew "bat"
                                brew "thefuck"
                                brew "gh"
                                brew "tree"
                                brew "sk"
                                brew "neovim-remote"
                                brew "cheat"
                                brew "trash"
                                brew "google-authenticator-libpam"
                                brew "ruby"
                                brew "pnpm"
            				  brew "asdf",args:["HEAD"]
                      brew "borders"
                      brew "joshmedeski/sesh/sesh"
                      brew "devbox"
      brew "uutils-coreutils"
    '';
  };
}
#                        	  brew "docker-compose"
# brew "ollama",args:["HEAD"]
# brew "zegervdv/zathura/zathura"
# brew "zegervdv/zathura/zathura-pdf-mupdf"
#           brew "koekeishiya/formulae/skhd",args:["HEAD"]
#           brew "koekeishiya/formulae/yabai",args:["HEAD"]
#           brew "anime-downloader"
#           brew "anime-downloader",args:["HEAD"]
#           brew "antigen"
# brew "sketchybar"
# brew "tmux",args:["HEAD"]

