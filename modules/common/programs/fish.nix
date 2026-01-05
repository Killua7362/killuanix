{ config, pkgs, ... }:

{

programs.fish = {

	enable = true;
    shellAliases = {
        "oil" = "~/killuanix/DotFiles/scripts/oil-ssh.sh";
        ".." = "cd ..";
        "ls" = "/home/killua/.nix-profile/bin/exa --color=auto --group-directories-first --classify";
        "lst" = "$ls --tree";
        "la" = "$ls --all";
        "ll" = "$ls --all --long --header --group";
        "llt" = "$ll --tree";
        "tree" = "$ls --tree";
        "cdtemp" = "cd `mktemp -d`";
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
        "ta" = "tmux a -t \$1";
        "td" = "tmux kill-session -t \$1";
        "tn" = "tmux new-session";
        "ts" = "~/killuanix/scripts/tmux-sessionizer.sh";
        "ovpn-connect" = "sudo openvpn --config vpn/goutam-pivotree.ovpn --auth-retry interact";
        "annepro2_tools" = "/home/killua/repo/AnnePro2-Tools/target/release/annepro2_tools";
        "d" = "nvim -d";
    };
    functions = {
    nix_switch = ''
        function nix_switch
            pushd ~/killuanix/
            env TERM=xterm-256color nix --extra-experimental-features 'flakes nix-command' build '.#homeManagerConfigurations.archnix.activationPackage'
            env TERM=xterm-256color ./result/activate
            popd
        end
        '';
        pacsave = ''
            function pacsave
                pushd ~/killuanix/archnix/aconfmgr/
                ./aconfmgr -c ~/.config/aconfmgr --aur-helper yay --yes save
                popd
            end
        '';
        pacapply = ''
            function pacapply
                pushd ~/killuanix/archnix/aconfmgr/
                ./aconfmgr -c ~/.config/aconfmgr --aur-helper yay --yes apply
                popd
            end
        '';
    };
	shellInit = ''

starship init fish | source

set -U fish_history_search_dedup 1
set -U fish_history_save_on_exit 1
set -g fish_confirm_history_expansion 1
set -g fish_autosuggestion_enabled 1
set -g fish_greeting
set -g fish_complete_case_insensitive 1

set -gx fish_color_valid_path --underline
set -gx COLORTERM truecolor
set -gx TERM xterm-256color
set -gx EDITOR nvim
set -gx LESS "~/.lesskey"
set -gx MANPAGER "nvim +Man!"
set -gx MANWIDTH 999
set -gx LG_CONFIG_FILE "$HOME/.config/lazygit.yml"
set -gx XDG_CONFIG_HOME "$HOME/.config"
set -gx XDG_DATA_DIRS "$HOME/.nix-profile/share:$XDG_DATA_DIRS"

set -x PATH "/home/killua/Downloads/java/jdk1.8.0_291/bin:$HOME/.npm-global/bin:$HOME/killuanix/DotFiles/scripts:$HOME/.local/bin:$PATH"
# set -x JAVA_HOME "$HOME/Documents/Boeing/java/jdk1.8.0_291"
#set -x JAVA_HOME "/home/killua/Documents/Boeing/jdk1.8.0_291/"
set -x JAVA_HOME "/home/killua/Downloads/java/jdk1.8.0_291"
set -x JBOSS_HOME "/home/killua/Documents/Boeing/jboss-eap-7.2"
set -x JBOSS_ROOT "/home/killua/Documents/Boeing/jboss-eap-7.2"
set -x EAR_LOC "/home/killua/Documents/Boeing/jboss-eap-7.2/data/EAR"
set -x ATG_HOME "/home/killua/ATG/ATG11.3.2"
set -x ATG_ROOT "/home/killua/ATG/ATG11.3.2"
set -x DYNAMO_HOME "/home/killua/ATG/ATG11.3.2/home"

set -x POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD true
set -x LANGUAGE en_US.UTF-8
set -x LC_ALL en_US.UTF-8
set -x LANG en_US.UTF-8
set -x LC_CTYPE en_US.UTF-8
set -x FZF_DEFAULT_COMMAND "fd --type f --hidden --follow"
set -x FZF_DEFAULT_OPTS "--height=60% --border --margin=1 --padding=1 --preview '~/killuanix/DotFiles/scripts/fzf/fzf-preview.sh {}' --bind 'ctrl-n:down,ctrl-p:up,ctrl-u:preview-up,ctrl-d:preview-down' --color=bg+:#293739,bg:#1B1D1E,border:#808080,spinner:#E6DB74,hl:#7E8E91,fg:#F8F8F2,header:#7E8E91,info:#A6E22E,pointer:#A6E22E,marker:#F92672,fg+:#F8F8F2,prompt:#F92672,hl+:#F92672"
set -x FZF_CTRL_T_OPTS ""
set -x FZF_COMPLETION_OPTS "--height=60% --border --margin=1 --padding=1"
set -x FZF_TMUX 1

zoxide init fish | source
set -U fifc_fd_opts --hidden
set -U fifc_bat_opts --style=numbers

set -g fish_color_command green
set -g fish_color_param cyan
set -g fish_color_error red --bold
set -g fish_color_comment brblack
set -g fish_color_autosuggestion brblack

bind ctrl-c __fish_cancel_commandline

set -x ZELLIJ_AUTO_EXIT false
set -x ZELLIJ_AUTO_ATTACH false

'';
};

}
