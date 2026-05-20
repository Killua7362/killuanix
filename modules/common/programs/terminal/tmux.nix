{
  config,
  pkgs,
  ...
}: let
  p = config.theme.palette;
in {
  programs.tmux = {
    enable = true;
    prefix = "C-a";
    keyMode = "vi";
    mouse = true;
    baseIndex = 1;
    escapeTime = 0;
    historyLimit = 1000000;
    terminal = "tmux-256color";
    shell = "${pkgs.zsh}/bin/zsh";

    plugins = with pkgs.tmuxPlugins; [
      sensible
      yank
      vim-tmux-navigator
    ];

    extraConfig = ''
      # --- general ---------------------------------------------------------
      set -ga terminal-overrides ",xterm-256color:RGB,ghostty:RGB"
      set -g focus-events on
      set -g renumber-windows on
      set -g set-clipboard on
      setw -g pane-base-index 1

      # double-tap prefix sends literal C-a (for nested sessions / readline)
      bind C-a send-prefix

      # --- splits (zellij muscle memory: h=vertical right, r=horizontal down)
      bind h split-window -h -c "#{pane_current_path}"
      bind r split-window -v -c "#{pane_current_path}"
      bind '|' split-window -h -c "#{pane_current_path}"
      bind '-' split-window -v -c "#{pane_current_path}"

      # --- pane nav (prefix + vim + colemak) -------------------------------
      bind j select-pane -D
      bind k select-pane -U
      bind n select-pane -L
      bind e select-pane -D
      bind i select-pane -U
      bind o select-pane -R

      # Alt-arrow nav (no prefix). vim-tmux-navigator handles Alt-h/j/k/l
      # forwarding into nvim panes.
      bind -n M-Left  select-pane -L
      bind -n M-Down  select-pane -D
      bind -n M-Up    select-pane -U
      bind -n M-Right select-pane -R

      # Alt-Colemak nav across panes; falls through to window cycle at edges
      # (mirrors zellij MoveFocusOrTab).
      bind -n M-n if-shell '[ "#{pane_at_left}"  = "1" ]' "previous-window" "select-pane -L"
      bind -n M-o if-shell '[ "#{pane_at_right}" = "1" ]' "next-window"     "select-pane -R"
      bind -n M-e select-pane -D
      bind -n M-i select-pane -U

      # --- windows (zellij "tabs") -----------------------------------------
      bind c new-window -c "#{pane_current_path}"
      bind -n M-h new-window -c "#{pane_current_path}"
      bind -n M-w kill-pane
      bind -n "M-[" previous-window
      bind -n "M-]" next-window
      bind -n M-I swap-window -t -1 \; previous-window
      bind -n M-O swap-window -t +1 \; next-window
      bind -n C-Tab next-window
      bind -n C-S-Tab previous-window

      # numeric jumps prefix+1..9
      bind 1 select-window -t :1
      bind 2 select-window -t :2
      bind 3 select-window -t :3
      bind 4 select-window -t :4
      bind 5 select-window -t :5
      bind 6 select-window -t :6
      bind 7 select-window -t :7
      bind 8 select-window -t :8
      bind 9 select-window -t :9

      # --- resize ----------------------------------------------------------
      bind -n "M-+" resize-pane -U 2
      bind -n "M-=" resize-pane -D 2
      bind -n "M--" resize-pane -D 2
      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 3
      bind -r K resize-pane -U 3
      bind -r L resize-pane -R 5

      # --- zoom / kill -----------------------------------------------------
      bind f resize-pane -Z
      bind x kill-pane
      bind X kill-window
      bind -n M-f resize-pane -Z

      # --- floating panes via popup (zellij Alt-t / ToggleFloatingPanes) ---
      bind w display-popup -E -w 80% -h 80% -d "#{pane_current_path}" "$SHELL"
      bind -n M-t display-popup -E -w 80% -h 80% -d "#{pane_current_path}" "$SHELL"

      # --- session picker --------------------------------------------------
      bind s choose-tree -Zs
      bind -n M-s choose-tree -Zs
      bind d detach-client

      # --- project picker (zellij Alt-p / zj-proj) -------------------------
      bind -n M-p display-popup -E -w 80% -h 80% \
        "${config.home.homeDirectory}/killuanix/scripts/zj-proj"
      bind p display-popup -E -w 80% -h 80% \
        "${config.home.homeDirectory}/killuanix/scripts/zj-proj"

      # --- copy mode (vi) + wl-copy ----------------------------------------
      bind [ copy-mode
      bind -n C-s copy-mode
      bind -T copy-mode-vi v send-keys -X begin-selection
      bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "${pkgs.wl-clipboard}/bin/wl-copy"
      bind -T copy-mode-vi Y send-keys -X copy-pipe-and-cancel "${pkgs.wl-clipboard}/bin/wl-copy"
      bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-no-clear "${pkgs.wl-clipboard}/bin/wl-copy"

      # --- edit scrollback in nvim (zellij Ctrl-a v) -----------------------
      bind v run-shell ' \
        f=$(mktemp --suffix=.log); \
        tmux capture-pane -p -S -1000000 -t "#{pane_id}" > "$f"; \
        tmux new-window "${pkgs.neovim}/bin/nvim + $f"'

      # --- reload ----------------------------------------------------------
      bind R source-file ~/.config/tmux/tmux.conf \; display "tmux reloaded"

      # --- status bar (palette-driven) -------------------------------------
      set -g status on
      set -g status-interval 5
      set -g status-position bottom
      set -g status-justify left
      set -g status-style "bg=${p.zellij_bg},fg=${p.fg}"

      set -g status-left-length 40
      set -g status-right-length 80
      set -g status-left  "#[bg=${p.color4},fg=${p.bg},bold] #S #[bg=${p.zellij_bg},fg=${p.color4}] "
      set -g status-right "#[fg=${p.color9}] #h #[fg=${p.color4}]| #[fg=${p.fg}]%Y-%m-%d %H:%M "

      setw -g window-status-format         "#[fg=${p.fg},bg=${p.zellij_bg}]  #I:#W  "
      setw -g window-status-current-format "#[fg=${p.bg},bg=${p.color4},bold]  #I:#W  "
      setw -g window-status-activity-style "fg=${p.color3},bg=${p.zellij_bg}"

      set -g pane-border-style        "fg=${p.color0}"
      set -g pane-active-border-style "fg=${p.color4}"
      set -g message-style            "bg=${p.color4},fg=${p.bg}"
      set -g mode-style               "bg=${p.color4},fg=${p.bg}"
      set -g display-panes-active-colour "${p.color9}"
      set -g display-panes-colour        "${p.color4}"
    '';
  };
}
