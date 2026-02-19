 { config, pkgs, ... }:

{
  programs.zsh = {
    enable = true;
    enableCompletion = false;

    # History settings
    history = {
      size = 10000;
      save = 10000;
      ignoreDups = true;
      ignoreAllDups = true;
      share = true;
    };

    shellAliases = {
      "oil" = "~/killuanix/DotFiles/scripts/oil-ssh.sh";
      ".." = "cd ..";
      "ls" = "eza --color=auto --group-directories-first --classify";
      "lst" = "eza --color=auto --group-directories-first --classify --tree";
      "la" = "eza --color=auto --group-directories-first --classify --all";
      "ll" = "eza --color=auto --group-directories-first --classify --all --long --header --group";
      "llt" = "eza --color=auto --group-directories-first --classify --all --long --header --group --tree";
      "tree" = "eza --color=auto --group-directories-first --classify --tree";
      "cdtemp" = "cd $(mktemp -d)";
      "cp" = "cp -iv";
      "ln" = "ln -v";
      "mkdir" = "mkdir -vp";
      "mv" = "mv -iv";
      "dh" = "du -h";
      "df" = "df -h";
      "su" = "sudo -E su -m";
      "sysu" = "systemctl --user";
      "jnsu" = "journalctl --user";
      "svim" = "sudoedit";
      "c" = "clear";
      "t" = "tmux attach || tmux";
      "tl" = "tmux ls";
      "tn" = "tmux new-session";
      "ts" = "~/killuanix/scripts/tmux-sessionizer.sh";
      "ovpn-connect" = "sudo openvpn --config vpn/goutam-pivotree.ovpn --auth-retry interact";
      "annepro2_tools" = "/home/killua/repo/AnnePro2-Tools/target/release/annepro2_tools";
      "d" = "nvim -d";
    };

    sessionVariables = {
      COLORTERM = "truecolor";
      TERM = "xterm-256color";
      EDITOR = "nvim";
      LESS = "~/.lesskey";
      MANPAGER = "nvim +Man!";
      MANWIDTH = "999";
      LG_CONFIG_FILE = "$HOME/.config/lazygit.yml";
      XDG_CONFIG_HOME = "$HOME/.config";
      
      JAVA_HOME = "/home/killua/Downloads/java/jdk1.8.0_291";
      JBOSS_HOME = "/home/killua/Documents/Boeing/jboss-eap-7.2";
      JBOSS_ROOT = "/home/killua/Documents/Boeing/jboss-eap-7.2";
      EAR_LOC = "/home/killua/Documents/Boeing/jboss-eap-7.2/data/EAR";
      ATG_HOME = "/home/killua/ATG/ATG11.3.2";
      ATG_ROOT = "/home/killua/ATG/ATG11.3.2";
      DYNAMO_HOME = "/home/killua/ATG/ATG11.3.2/home";
      
      POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD = "true";
      LANGUAGE = "en_US.UTF-8";
      LC_ALL = "en_US.UTF-8";
      LANG = "en_US.UTF-8";
      LC_CTYPE = "en_US.UTF-8";
      
      FZF_DEFAULT_COMMAND = "fd --type f --hidden --follow";
      FZF_DEFAULT_OPTS = "--height=60% --border --margin=1 --padding=1 --preview '~/killuanix/DotFiles/scripts/fzf/fzf-preview.sh {}' --bind 'ctrl-n:down,ctrl-p:up,ctrl-u:preview-up,ctrl-d:preview-down' --color=bg+:#293739,bg:#1B1D1E,border:#808080,spinner:#E6DB74,hl:#7E8E91,fg:#F8F8F2,header:#7E8E91,info:#A6E22E,pointer:#A6E22E,marker:#F92672,fg+:#F8F8F2,prompt:#F92672,hl+:#F92672 --bind 'start:execute-silent(zellij action switch-mode locked 2>/dev/null)+reload(true)' --bind 'abort:execute-silent(zellij action switch-mode normal 2>/dev/null)'";
      FZF_CTRL_T_OPTS = "";
      FZF_COMPLETION_OPTS = "--height=60% --border --margin=1 --padding=1";
      FZF_TMUX = "1";
      
      ZELLIJ_AUTO_EXIT = "false";
      ZELLIJ_AUTO_ATTACH = "false";
    };

    initContent = ''

      fpath=(/usr/share/zsh/site-functions /usr/share/zsh/functions/Completion/{Linux,Unix} $fpath)

      # PATH modifications
      export PATH="/home/killua/Downloads/java/jdk1.8.0_291/bin:$HOME/.npm-global/bin:$HOME/killuanix/DotFiles/scripts:$HOME/.local/bin:$PATH"
      export XDG_DATA_DIRS="$HOME/.nix-profile/share:$XDG_DATA_DIRS"

      autoload -Uz compinit
      local zcdump="$HOME/.zcompdump"
      if [[ -n "$zcdump"(#qN.mh+24) ]]; then
        compinit -i -d "$zcdump"
        { zcompile "$zcdump" } &!
      else
        compinit -C -d "$zcdump"
      fi

      eval $(starship init zsh)
      eval $(zoxide init zsh)

      # Re-source plugins AFTER zsh-vi-mode initializes so keybindings survive
      zvm_after_init() {
        [[ -n "\'\'$\{functions[fzf_history_search]\}" ]] && \
          bindkey -M viins '^R' fzf_history_search
      }

      zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
      zstyle ':completion:*:git-checkout:*' sort false
      zstyle ':completion:*:descriptions' format '[%d]'
      zstyle ':completion:*' menu no
      zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
      zstyle ':fzf-tab:*' switch-group '<' '>'

      # Functions (converted from fish)
      nix_switch() {
        pushd ~/killuanix/
        TERM=xterm-256color nix --extra-experimental-features 'flakes nix-command' build '.#homeManagerConfigurations.archnix.activationPackage'
        TERM=xterm-256color ./result/activate
        popd
      }

      pacsave() {
        pushd ~/killuanix/archnix/aconfmgr/
        ./aconfmgr -c ~/.config/aconfmgr --aur-helper yay --yes save
        popd
      }

      pacapply() {
        pushd ~/killuanix/archnix/aconfmgr/
        ./aconfmgr -c ~/.config/aconfmgr --aur-helper yay --yes apply
        popd
      }

      # Tmux functions (need arguments, so functions instead of aliases)
      ta() { tmux a -t "$1"; }
      td() { tmux kill-session -t "$1"; }

      # Disable greeting (zsh doesn't have this by default anyway)
      # Key bindings
      bindkey '^C' send-break
      
      bindkey -M viins "^[[H" beginning-of-line
      bindkey -M viins "^[[F" end-of-line
      
      bindkey -M viins '^[[1;5C' forward-word   # Ctrl+Right
      bindkey -M viins '^[[1;5D' backward-word  # Ctrl+Left

      bindkey "\'\'$\{key[Up]\}" up-line-or-search

      [[ ! -v functions[command_not_found_handler] ]] || unfunction command_not_found_handler

      # Also unlock after fzf exits normally
      function fzf() {
        command fzf "$@"
        local ret=$?
        zellij action switch-mode normal 2>/dev/null
        return $ret
      }
    '';
    antidote = {
        enable = true;
        plugins = [
          "getantidote/use-omz"
          "jeffreytse/zsh-vi-mode"
          "Aloxaf/fzf-tab"
          "joshskidmore/zsh-fzf-history-search"
          "Bhupesh-V/ugit"
          "babarot/enhancd"
          "ohmyzsh/ohmyzsh path:lib"
          "ohmyzsh/ohmyzsh path:plugins/extract"
          "ohmyzsh/ohmyzsh path:plugins/colored-man-pages"
          "ohmyzsh/ohmyzsh path:plugins/copybuffer"
          "ohmyzsh/ohmyzsh path:plugins/copyfile"
          "ohmyzsh/ohmyzsh path:plugins/copypath"
          "ohmyzsh/ohmyzsh path:plugins/extract"
          "ohmyzsh/ohmyzsh path:plugins/globalias"
          "ohmyzsh/ohmyzsh path:plugins/magic-enter"
          "ohmyzsh/ohmyzsh path:plugins/fancy-ctrl-z"
          "ohmyzsh/ohmyzsh path:plugins/otp"
          "ohmyzsh/ohmyzsh path:plugins/zoxide"
          "ohmyzsh/ohmyzsh path:plugins/git"
          "ohmyzsh/ohmyzsh path:plugins/golang"
          "ohmyzsh/ohmyzsh path:plugins/python"
          "romkatv/zsh-bench kind:path"
          "zsh-users/zsh-completions path:src kind:fpath"
          "zsh-users/zsh-autosuggestions"
          "zsh-users/zsh-history-substring-search"
          "zdharma-continuum/fast-syntax-highlighting"
          "wfxr/forgit"
          # "zsh-users/zsh-autosuggestions"
          # "zsh-users/zsh-syntax-highlighting"
        ];
        useFriendlyNames = true;
      };
  };
}
