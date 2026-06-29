{
  config,
  pkgs,
  lib,
  ...
}: {
  programs.zsh = {
    enable = true;
    dotDir = config.home.homeDirectory;
    enableCompletion = false;

    # History settings
    history = {
      size = 100000;
      save = 100000;
      ignoreDups = true;
      ignoreAllDups = true;
      share = true;
    };

    shellAliases = {
      "oil" = "~/killuanix/DotFiles/scripts/oil-ssh.sh";
      ".." = "cd ..";
      "ls" = "eza --color=auto --group-directories-first --classify always";
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
      "restart-desktop" = "systemctl --user restart xdg-desktop-portal-hyprland xdg-desktop-portal pipewire pipewire-pulse wireplumber";
      "lgw" = "lazygit -g \"$(git rev-parse --git-common-dir)\" -w .";
    };

    sessionVariables = {
      COLORTERM = "truecolor";
      TERM = "xterm-256color";
      EDITOR = "nvim";
      LESS = "~/.lesskey";
      MANPAGER = "nvim +Man!";
      MANWIDTH = "999";
      LG_CONFIG_FILE = "$HOME/.config/lazygit/config.yml";
      XDG_CONFIG_HOME = "$HOME/.config";

      JAVA_HOME = "/home/killua/Downloads/java/jdk1.8.0_291";
      JBOSS_HOME = "/home/killua/Documents/jboss-eap-7.2";
      JBOSS_ROOT = "/home/killua/Documents/jboss-eap-7.2";
      EAR_LOC = "/home/killua/Documents/jboss-eap-7.2/data/EAR";
      ATG_HOME = "/home/killua/ATG/ATG11.3.2";
      ATG_ROOT = "/home/killua/ATG/ATG11.3.2";
      DYNAMO_HOME = "/home/killua/ATG/ATG11.3.2/home";
      DYNAMO_ROOT = "/home/killua/ATG/ATG11.3.2";

      POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD = "true";
      LANGUAGE = "en_US.UTF-8";
      LC_ALL = "en_US.UTF-8";
      LANG = "en_US.UTF-8";
      LC_CTYPE = "en_US.UTF-8";

      FZF_DEFAULT_COMMAND = "fd --type f --hidden --follow";
      FZF_DEFAULT_OPTS = "--height=60% --border --margin=1 --padding=1 --preview '~/killuanix/DotFiles/scripts/fzf/fzf-preview.sh {}' --bind 'ctrl-n:down,ctrl-p:up,ctrl-u:preview-up,ctrl-d:preview-down' --color=bg+:#293739,bg:#1B1D1E,border:#808080,spinner:#E6DB74,hl:#7E8E91,fg:#F8F8F2,header:#7E8E91,info:#A6E22E,pointer:#A6E22E,marker:#F92672,fg+:#F8F8F2,prompt:#F92672,hl+:#F92672";
      FZF_CTRL_T_OPTS = "";
      FZF_COMPLETION_OPTS = "--height=60% --border --margin=1 --padding=1";
      FZF_TMUX = "1";
    };

    initContent = lib.mkAfter ''

      if [ -e "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
        . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
      fi

      export PATH="$HOME/.nix-profile/bin:$PATH"

        fpath=(/usr/share/zsh/site-functions /usr/share/zsh/functions/Completion/{Linux,Unix} $fpath)

        # PATH modifications
        export PATH="$HOME/killuanix/scripts:/home/killua/Downloads/java/jdk1.8.0_291/bin:$HOME/.npm-global/bin:$HOME/killuanix/DotFiles/scripts:$HOME/.local/bin:$PATH"
        export XDG_DATA_DIRS="$HOME/.nix-profile/share:$XDG_DATA_DIRS"

        autoload -Uz compinit
        compinit -d "''${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump-$ZSH_VERSION"
        eval $(starship init zsh)
        eval $(zoxide init zsh)

        # Re-source plugins AFTER zsh-vi-mode initializes so keybindings survive
        zvm_after_init() {
          [[ -n "\'\'$\{functions[fzf_history_search]\}" ]] && \
            bindkey -M viins '^R' fzf_history_search
        }

        # Colemak remappings for zsh vi mode (mirrors neovim keymaps.lua)
        zvm_after_lazy_keybindings() {
          # NEIO navigation (replaces HJKL)
          bindkey -M vicmd 'n' vi-backward-char        # n → h (left)
          bindkey -M vicmd 'e' down-line-or-history     # e → j (down)
          bindkey -M vicmd 'i' up-line-or-history       # i → k (up)
          bindkey -M vicmd 'o' vi-forward-char          # o → l (right)

          # Displaced keys
          bindkey -M vicmd 'u' vi-insert                # u → i (insert)
          bindkey -M vicmd 'U' vi-insert-bol            # U → I (insert at bol)
          bindkey -M vicmd 'y' vi-open-line-below       # y → o (open line below)
          bindkey -M vicmd 'Y' vi-open-line-above       # Y → O (open line above)
          bindkey -M vicmd 'j' vi-forward-word-end      # j → e (end of word)
          bindkey -M vicmd 'h' vi-repeat-search         # h → n (next search)
          bindkey -M vicmd 'H' vi-rev-repeat-search     # H → N (prev search)
          bindkey -M vicmd 'k' undo                     # k → u (undo)
          bindkey -M vicmd 'l' vi-yank                  # l → y (yank)

          # Visual mode
          bindkey -M visual 'n' vi-backward-char
          bindkey -M visual 'e' down-line-or-history
          bindkey -M visual 'i' up-line-or-history
          bindkey -M visual 'o' vi-forward-char
          bindkey -M visual 'j' vi-forward-word-end
        }

        zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
        zstyle ':completion:*:git-checkout:*' sort false
        zstyle ':completion:*:descriptions' format '[%d]'
        zstyle ':completion:*' menu no
        zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
        zstyle ':fzf-tab:*' switch-group '<' '>'

        # Functions (converted from fish)
        boeingvpn() {
          # usage: boeingvpn [userid] [gateway-host]
          # userid : positional $1 overrides; else default from sops
          #          (boeing/vpn_userid at ${config.sops.secrets."boeing/vpn_userid".path})
          # gateway: positional $2 or $BOEINGVPN_GATEWAY overrides; else auto-pick
          #          lowest TCP-connect RTT across the gateway list.
          local userid="''${1:-}"
          if [ -z "$userid" ]; then
            userid="$(cat ${config.sops.secrets."boeing/vpn_userid".path} 2>/dev/null)"
          fi
          if [ -z "$userid" ]; then
            echo "boeingvpn: no userid (pass as arg or set boeing/vpn_userid in sops)" >&2
            return 1
          fi

          local gw="''${2:-''${BOEINGVPN_GATEWAY:-}}"
          if [ -z "$gw" ]; then
            local hosts=(
              ta.eu1.cbc.vpn.boeing.net   # Amsterdam E
              ta.eu2.cbc.vpn.boeing.net   # Amsterdam F
              ta.au1.cbc.vpn.boeing.net   # Brisbane E
              ta.au2.cbc.vpn.boeing.net   # Melbourne E
              ta.nw1.cbc.vpn.boeing.net   # Northwest E
              ta.nw2.cbc.vpn.boeing.net   # Northwest F
              ta.se1.cbc.vpn.boeing.net   # Southeast 1
              ta.se2.cbc.vpn.boeing.net   # Southeast 2
              ta.sw1.cbc.vpn.boeing.net   # Southwest E
              ta.sw2.cbc.vpn.boeing.net   # Southwest F
              ta.as1.cbc.vpn.boeing.net   # Tokyo E
              ta.as2.cbc.vpn.boeing.net   # Tokyo F
            )
            local samples="''${BOEINGVPN_SAMPLES:-3}"
            local deadline="''${BOEINGVPN_DEADLINE:-15}"   # hard wall-clock cap (s)
            local ctimeout="''${BOEINGVPN_CONNECT_TIMEOUT:-2}"
            echo "boeingvpn: probing $#hosts gateways ($samples samples, median RTT, ''${deadline}s cap)..." >&2
            local h t i ms best="" bestms=999999
            SECONDS=0   # wall-clock timer
            for h in "''${hosts[@]}"; do
              # Hard cap: stop probing once the deadline passes, use best so far.
              if (( SECONDS >= deadline )); then
                echo "boeingvpn: deadline ''${deadline}s hit, using best so far" >&2
                break
              fi
              # time_connect = TCP RTT to :443. TLS skipped (Boeing gateways
              # need unsafe legacy renegotiation; OpenSSL refuses it). 0 = down.
              # Median of N samples so one slow handshake can't crown a loser.
              local vals=()
              for ((i = 0; i < samples; i++)); do
                t=$(curl -ks --connect-timeout "$ctimeout" --max-time "$ctimeout" -o /dev/null -w '%{time_connect}' "https://$h" 2>/dev/null || true)
                if [ -n "$t" ] && [ "$t" != "0" ] && [ "$t" != "0.000000" ]; then
                  vals+=("$t")
                elif (( ''${#vals[@]} == 0 && i >= 1 )); then
                  # two leading failures, no success -> host down, stop retrying.
                  # (not on first failure: cold DNS sample can exceed the timeout.)
                  break
                fi
              done
              [ ''${#vals[@]} -eq 0 ] && continue
              ms=$(printf '%s\n' "''${vals[@]}" | sort -n | awk '
                { v[NR] = $1 }
                END {
                  n = NR
                  if (n % 2) m = v[(n + 1) / 2]
                  else       m = (v[n / 2] + v[n / 2 + 1]) / 2
                  printf "%d", m * 1000
                }')
              [ "$ms" -le 0 ] && continue
              if [ "$ms" -lt "$bestms" ]; then bestms="$ms"; best="$h"; fi
            done
            if [ -z "$best" ]; then
              echo "boeingvpn: no gateway reachable" >&2
              return 1
            fi
            gw="$best"
            echo "boeingvpn: fastest = $gw (''${bestms}ms)" >&2
          fi

          openconnect \
              --protocol=gp \
              --user="$userid" \
              --usergroup=gateway \
              --script-tun \
              --script "ocproxy -D 1080 -v" \
              "https://$gw"
        }

        chrome-socks() {
          # boeingvpn-ui SOCKS via --proxy-server (socks5h equivalent —
          # proxy-side DNS, needed for split-horizon Boeing endpoints).
          # For 10.55.* dev VNet URLs, use `avd-chrome` instead (separate
          # profile + SOCKS via bastion-sql's ssh -D :11180).
          google-chrome \
            --proxy-server="socks5://127.0.0.1:1080" \
            --proxy-bypass-list="127.0.0.1" \
            --user-data-dir="$HOME/.config/teams-vpn-chrome" \
            --no-first-run \
            --ignore-certificate-errors
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

        # Preserve scrollback when clearing under zellij/tmux: skip the E3
        # (clear-scrollback) sequence that ncurses' `clear` emits.
        clear() { printf '\e[H\e[2J'; }

        # Disable greeting (zsh doesn't have this by default anyway)
        # Key bindings
        bindkey '^C' send-break

        bindkey -M viins "^[[H" beginning-of-line
        bindkey -M viins "^[[F" end-of-line

        bindkey -M viins '^[[1;5C' forward-word   # Ctrl+Right
        bindkey -M viins '^[[1;5D' backward-word  # Ctrl+Left

        bindkey "\'\'$\{key[Up]\}" up-line-or-search

        # command-not-found disable
        # [[ ! -v functions[command_not_found_handler] ]] || unfunction command_not_found_handler

        bindkey -M emacs "^ " globalias
        bindkey -M viins "^ " globalias
        bindkey -M emacs " " magic-space
        bindkey -M viins " " magic-space

        opencode() {
          local PROJ="$(basename "$(pwd)")"
          local NAME="open-code-''${PROJ}"

          podman run --userns=keep-id --rm --tty --interactive \
            --name "''${NAME}" \
            --add-host=host.docker.internal:host-gateway \
            -v "''${HOME}/.local/state/opencode:/home/node/.local/state/opencode" \
            -v "''${HOME}/.local/share/opencode:/home/node/.local/share/opencode" \
            -v "''${HOME}/.config/opencode:/home/node/.config/opencode" \
            -v "$(pwd):/app:rw" \
            open-code "''$@"
        }

        # Boot three zellij sessions in parallel, attach to killuanix.
        # bdsi + mod spawn detached via `script` (zellij needs a tty).
        zboot() {
          local bg=(
            "bdsi:$HOME"
            "mod:$HOME"
          )
          local existing
          existing=$(zellij list-sessions -s 2>/dev/null)
          for spec in "''${bg[@]}"; do
            local name="''${spec%%:*}" cwd="''${spec##*:}"
            if ! grep -qx "$name" <<<"$existing"; then
              script -qfc "zellij -s '$name' options --default-cwd '$cwd'" /dev/null \
                </dev/null >/dev/null 2>&1 &!
            fi
          done
          sleep 0.3
          zellij attach --create killuanix options --default-cwd "$HOME/killuanix"
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
