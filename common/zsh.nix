{ config, pkgs, lib, ... }:


{

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    enableCompletion = true;
    zplug = {
    enable = true;
    plugins = [
      { name = "zsh-users/zsh-syntax-highlighting"; } # Simple plugin installation
      { name = "zsh-users/zsh-autosuggestions"; } # Simple plugin installation
      { name = "b4b4r07/enhancd"; } # Simple plugin installation
      { name = "Bhupesh-V/ugit"; } # Simple plugin installation
      { name = "romkatv/powerlevel10k"; tags = [ as:theme depth:1 ]; } # Installations with additional options. For the list of options, please refer to Zplug README.
      {name = "Aloxaf/fzf-tab";}
    ];
  };
    plugins = [
      # Vi keybindings
     # {
     #   name = "zsh-vi-mode";
    #    file = "./share/zsh-vi-mode/zsh-vi-mode.plugin.zsh";
     #   src = pkgs.zsh-vi-mode;
     # }
    ];

    history = {
      expireDuplicatesFirst = true;
      ignoreDups = true;
      ignoreSpace = true;
      extended = true;
      path = "${config.xdg.dataHome}/zsh/history";
      share = false;
      size = 100000;
      save = 100000;
    };

    sessionVariables = {
      COLORTERM = "truecolor";
      TERM = "xterm-256color";
      EDITOR = "nvim";
      #ZVM_VI_ESCAPE_BINDKEY = "kl";
      LESS = "~/.lesskey";
      MANPAGER="nvim +Man!";
      MANWIDTH="999";
      KEYTIMEOUT = "1";  # Add this line - reduces escape key delay to 10ms
      LG_CONFIG_FILE="$HOME/.config/lazygit.yml";
    	XDG_CONFIG_HOME="$HOME/.config";
    	XDG_DATA_DIRS="$HOME/.nix-profile/share:$XDG_DATA_DIRS";
   };

    shellAliases = rec {
      ".."   = "cd ..";
      ls      = "${pkgs.eza}/bin/exa --color=auto --group-directories-first --classify";
      lst     = "${ls} --tree";
      la      = "${ls} --all";
      ll      = "${ls} --all --long --header --group";
      llt     = "${ll} --tree";
      tree    = "${ls} --tree";
      cdtemp  = "cd `mktemp -d`";
      cp      = "cp -iv";
      ln      = "ln -v";
      mkdir   = "mkdir -vp";
      mv      = "mv -iv";
      dh      = "du -h";
      df      = "df -h";
      su      = "sudo -E su -m";
      sysu    = "systemctl --user";
      jnsu    = "journalctl --user";
      svim    = "sudoedit";
      zreload = "export ZSH_RELOADING_SHELL=1; source $ZDOTDIR/.zshenv; source $ZDOTDIR/.zshrc; unset ZSH_RELOADING_SHELL";
      c = "clear";
       t="tmux attach || tmux";
	 tl="tmux ls";
	 ta="tmux a -t \$1";
	 td="tmux kill-session -t \$1";
	 tn="tmux new-session";
	 ts="~/killuanix/scripts/tmux-sessionizer.sh";
      ovpn-connect="sudo openvpn --config vpn/goutam-pivotree.ovpn --auth-retry interact";
    };

    profileExtra = ''
      setopt incappendhistory
      setopt histfindnodups
      setopt histreduceblanks
      setopt histverify
      setopt correct                                                  # Auto correct mistakes
      setopt extendedglob                                             # Extended globbing. Allows using regular expressions with *
      setopt nocaseglob                                               # Case insensitive globbing
      setopt rcexpandparam                                            # Array expension with parameters
      #setopt nocheckjobs                                              # Don't warn about running processes when exiting
      setopt numericglobsort                                          # Sort filenames numerically when it makes sense
      unsetopt nobeep                                                 # Enable beep
      setopt appendhistory                                            # Immediately append history instead of overwriting
      unsetopt histignorealldups                                      # If a new command is a duplicate, do not remove the older one
      setopt interactivecomments
      zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'       # Case insensitive tab completion
      zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"       # Colored completion (different colors for dirs/files/etc)
      zstyle ':completion:*' rehash true                              # automatically find new executables in path
      # Speed up completions
      zstyle ':completion:*' accept-exact '*(N)'
      zstyle ':completion:*' use-cache on
      mkdir -p "$(dirname ${config.xdg.cacheHome}/zsh/completion-cache)"
      zstyle ':completion:*' cache-path "${config.xdg.cacheHome}/zsh/completion-cache"
      zstyle ':completion:*' menu no
      WORDCHARS=''${WORDCHARS//\/[&.;]}                                 # Don't consider certain characters part of the word
    '';

    initContent = ''
      # Reload fzf binds after vi mode
      ## Keybindings section
      # vi movement keys on home row
      #bindkey -M vicmd j vi-backward-char
      #bindkey -M vicmd k vi-down-line-or-history
      #bindkey -M vicmd l vi-up-line-or-history
      #bindkey -M vicmd \; vi-forward-char
      bindkey -e
      bindkey '^[[7~' beginning-of-line                               # Home key
      bindkey '^[[H' beginning-of-line                                # Home key
      if [[ "''${terminfo[khome]}" != "" ]]; then
      bindkey "''${terminfo[khome]}" beginning-of-line                # [Home] - Go to beginning of line
      fi
      bindkey '^[[8~' end-of-line                                     # End key
      bindkey '^[[F' end-of-line                                     # End key
      if [[ "''${terminfo[kend]}" != "" ]]; then
      bindkey "''${terminfo[kend]}" end-of-line                       # [End] - Go to end of line
      fi
      bindkey '^[[2~' overwrite-mode                                  # Insert key
      bindkey '^[[3~' delete-char                                     # Delete key
      bindkey '^[[C'  forward-char                                    # Right key
      bindkey '^[[D'  backward-char                                   # Left key
      bindkey '^[[5~' history-beginning-search-backward               # Page up key
      bindkey '^[[6~' history-beginning-search-forward                # Page down key
      # Navigate words with ctrl+arrow keys
      bindkey '^[Oc' forward-word                                     #
      bindkey '^[Od' backward-word                                    #
      bindkey '^[[1;5D' backward-word                                 #
      bindkey '^[[1;5C' forward-word                                  #
      bindkey '^H' backward-kill-word                                 # delete previous word with ctrl+backspace
      bindkey '^[[Z' undo                                             # Shift+tab undo last action
      # Theming section
      autoload -U colors
      colors

      ## VERY IMPORTANT!!!!
      unset RPS1 RPROMPT

      export PATH="/usr/share/sway-contrib:$HOME/java-8/jdk1.8.0_291/bin:$HOME/killuanix/archnix/aconfmgr:$HOME/killuanix/DotFiles/scripts:$HOME/.local/bin:$PATH"
      export JAVA_HOME="$HOME/java-8/jdk1.8.0_291"
      export JBOSS_HOME="/home/killua/jboss"
      export JBOSS_ROOT="/home/killua/jboss"
      export EAR_LOC="/home/killua/jboss/data/EAR"
      export ATG_HOME="/home/killua/ATG/ATG11.3.2"
      export ATG_ROOT="/home/killua/ATG/ATG11.3.2"
      export DYNAMO_HOME="/home/killua/ATG/ATG11.3.2/home"

      export POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true
      export LANGUAGE=en_US.UTF-8
      export LC_ALL=en_US.UTF-8
      export LANG=en_US.UTF-8
      export LC_CTYPE=en_US.UTF-8
      export ENHANCD_FILTER="fzf --height=60% --border --margin=1 --padding=1"
      export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow"
      export FZF_DEFAULT_OPTS=" --preview '~/killuanix/scripts/fzf/fzf-preview.sh {}' --bind 'ctrl-n:down,ctrl-p:up,ctrl-u:preview-up,ctrl-d:preview-down' --color=bg+:#293739,bg:#1B1D1E,border:#808080,spinner:#E6DB74,hl:#7E8E91,fg:#F8F8F2,header:#7E8E91,info:#A6E22E,pointer:#A6E22E,marker:#F92672,fg+:#F8F8F2,prompt:#F92672,hl+:#F92672"
    	export FZF_CTRL_T_OPTS=""
    	export FZF_COMPLETION_OPTS="--height=60% --border --margin=1 --padding=1"
    	export FZF_TMUX="1"
        zstyle ':completion:*:git-checkout:*' sort false
        zstyle ':completion:*:descriptions' format '[%d]'
        zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
        zstyle ':fzf-tab:*' fzf-flags --color=fg:1,fg+:2 --bind=tab:accept
        zstyle ':fzf-tab:*' use-fzf-default-opts yes
        zstyle ':fzf-tab:*' switch-group '<' '>'
        zstyle ':fzf-tab:*' fzf-command ftb-tmux-popup

      source <(fzf --zsh)
     if [[ "$(tty)" == "/dev/tty4" ]]; then
       exec uwsm start hyprland-uwsm.desktop
     fi

     if [[ "$(tty)" == "/dev/tty2" ]]; then
       exec uwsm start sway-uwsm.desktop
     fi

      nix_switch()
      	{
      	  pushd ~/killuanix/
      	  env TERM=xterm-256color nix --extra-experimental-features 'flakes nix-command' build '.#homeManagerConfigurations.archnix.activationPackage' --extra-deprecated-features url-literals
      	  env TERM=xterm-256color ./result/activate
      	  popd
      	}

        pacsave(){
            pushd ~/killuanix/archnix/aconfmgr/
            ./aconfmgr -c ~/.config/aconfmgr --aur-helper yay --yes save
            popd
        }

        pacapply(){
            pushd ~/killuanix/archnix/aconfmgr/
            ./aconfmgr -c ~/.config/aconfmgr --aur-helper yay --yes apply
            popd
        }

        function boeing-db {
          case "$1" in 
              start)   VBoxManage startvm "oracle-19c-vagrant" --type headless ;;
              stop)    VBoxManage controlvm "oracle-19c-vagrant" poweroff ;;
              *) echo "usage: $0 start|stop" >&2
                 ;;
          esac
        }
    '';
  };
}
