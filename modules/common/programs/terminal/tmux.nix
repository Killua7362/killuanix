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
      # ====================================================================
      # general
      # ====================================================================
      set -ga terminal-overrides ",xterm-256color:RGB,ghostty:RGB"
      set -g focus-events on
      set -g renumber-windows on
      set -g set-clipboard on
      setw -g pane-base-index 1

      # double-tap prefix sends literal C-a (nested sessions / readline)
      bind C-a send-prefix

      # autolock-equivalent: when the focused pane runs nvim / fzf /
      # lazygit / etc. the mode-entry chord (Ctrl+n/p/s/t/h/m) passes
      # through to the program instead of switching tmux's key-table.
      # Matches the zellij-autolock trigger set. Claude is intentionally
      # NOT in this list (see Notes/claude/memory/project_zellij_autolock_claude.md).
      is_autolocked="ps -o state=,comm= -t '#{pane_tty}' | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?(n?vim?x?|vi|view|git|fzf|zoxide|atuin|git-forgit|lazygit|zj-proj|ghgrab)(diff)?$'"

      # quit (zellij Ctrl q)
      bind -n C-q confirm-before -p "kill tmux server? (y/n)" kill-server

      # lock (zellij Ctrl g) — empty key-table that swallows everything
      # except Ctrl-g to return.
      bind -n C-g switch-client -T locked
      bind -T locked C-g switch-client -T root
      bind -T locked Escape switch-client -T root

      # ====================================================================
      # prefix-level splits (zellij muscle memory: h vertical, r horizontal)
      # ====================================================================
      bind h split-window -h -c "#{pane_current_path}"
      bind r split-window -v -c "#{pane_current_path}"
      bind '|' split-window -h -c "#{pane_current_path}"
      bind '-' split-window -v -c "#{pane_current_path}"

      # ====================================================================
      # prefix-level pane nav (vim + colemak)
      # ====================================================================
      bind j select-pane -D
      bind k select-pane -U
      bind n select-pane -L
      bind e select-pane -D
      bind i select-pane -U
      bind o select-pane -R

      # ====================================================================
      # alt-arrow + alt-colemak pane nav (no prefix)
      # vim-tmux-navigator already handles M-h / M-j / M-k / M-l
      # ====================================================================
      bind -n M-Left  select-pane -L
      bind -n M-Down  select-pane -D
      bind -n M-Up    select-pane -U
      bind -n M-Right select-pane -R

      # alt-colemak across panes; fall through to window cycle at edges
      # (zellij MoveFocusOrTab)
      bind -n M-n if-shell '[ "#{pane_at_left}"  = "1" ]' "previous-window" "select-pane -L"
      bind -n M-o if-shell '[ "#{pane_at_right}" = "1" ]' "next-window"     "select-pane -R"
      bind -n M-e select-pane -D
      bind -n M-i select-pane -U

      # ====================================================================
      # alt-level windows + layout
      # ====================================================================
      bind -n M-h new-window -c "#{pane_current_path}"
      bind -n M-w kill-pane
      bind -n M-f resize-pane -Z
      bind -n M-t display-popup -E -w 80% -h 80% -d "#{pane_current_path}" "$SHELL"
      bind -n M-s choose-tree -Zs
      bind -n M-p display-popup -E -w 80% -h 80% \
        "${config.home.homeDirectory}/killuanix/scripts/zj-proj"

      # zellij Alt [ / Alt ] = swap layout (NOT window cycle)
      bind -n "M-[" previous-layout
      bind -n "M-]" next-layout

      # zellij Alt-Shift-i / Alt-Shift-o = move window
      bind -n M-I swap-window -t -1 \; previous-window
      bind -n M-O swap-window -t +1 \; next-window

      # Ctrl-Tab / Ctrl-Shift-Tab window cycle is delivered as Alt-./Alt-,
      # by ghostty (see ghostty.nix) — the M-, / M-. binds below handle it.
      # Direct CSI u (\e[9;5u / \e[9;6u) attempted previously but tmux 3.6a
      # normalizes Ctrl on Tab (Tab=^I) and forwards as legacy \e[Z, missing
      # every C-Tab / C-S-Tab / S-Tab / user-key bind.

      # reliable Alt-,/Alt-. fallback (zero terminal-encoding ambiguity)
      bind -n M-, previous-window
      bind -n M-. next-window

      # alt-resize
      bind -n "M-+" resize-pane -U 2
      bind -n "M-=" resize-pane -D 2
      bind -n "M--" resize-pane -D 2

      # ====================================================================
      # prefix-level shortcuts
      # ====================================================================
      bind c new-window -c "#{pane_current_path}"
      bind f resize-pane -Z
      bind x kill-pane
      bind X kill-window
      bind w display-popup -E -w 80% -h 80% -d "#{pane_current_path}" "$SHELL"
      bind p display-popup -E -w 80% -h 80% \
        "${config.home.homeDirectory}/killuanix/scripts/zj-proj"
      bind s choose-tree -Zs
      bind d detach-client

      # numeric jumps 1..9
      bind 1 select-window -t :1
      bind 2 select-window -t :2
      bind 3 select-window -t :3
      bind 4 select-window -t :4
      bind 5 select-window -t :5
      bind 6 select-window -t :6
      bind 7 select-window -t :7
      bind 8 select-window -t :8
      bind 9 select-window -t :9

      # prefix-resize (repeatable)
      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 3
      bind -r K resize-pane -U 3
      bind -r L resize-pane -R 5

      # ====================================================================
      # mode key-tables — port zellij Ctrl+<letter> mode entries
      # Each table exits on Esc, the same Ctrl+key (toggle), or Enter.
      # Mutating actions return to root; navigation stays in table.
      # ====================================================================

      # ---- pane mode (Ctrl-p) -------------------------------------------
      bind -n C-p if-shell "$is_autolocked" "send-keys C-p" "switch-client -T paneMode"
      bind -T paneMode Escape switch-client -T root
      bind -T paneMode Enter  switch-client -T root
      bind -T paneMode C-p    switch-client -T root
      bind -T paneMode h { split-window -h -c "#{pane_current_path}" ; switch-client -T root }
      bind -T paneMode d { split-window -v -c "#{pane_current_path}" ; switch-client -T root }
      bind -T paneMode r { split-window -h -c "#{pane_current_path}" ; switch-client -T root }
      bind -T paneMode f { resize-pane -Z ; switch-client -T root }
      bind -T paneMode w { display-popup -E -w 80% -h 80% -d "#{pane_current_path}" "$SHELL" ; switch-client -T root }
      bind -T paneMode c { command-prompt -p "rename pane:" "select-pane -T '%%'" ; switch-client -T root }
      bind -T paneMode x { kill-pane ; switch-client -T root }
      bind -T paneMode z { set -w pane-border-status ; switch-client -T root }
      bind -T paneMode p { select-pane -t :.+ ; switch-client -T paneMode }
      bind -T paneMode Left  { select-pane -L ; switch-client -T paneMode }
      bind -T paneMode Down  { select-pane -D ; switch-client -T paneMode }
      bind -T paneMode Up    { select-pane -U ; switch-client -T paneMode }
      bind -T paneMode Right { select-pane -R ; switch-client -T paneMode }
      bind -T paneMode j { select-pane -D ; switch-client -T paneMode }
      bind -T paneMode k { select-pane -U ; switch-client -T paneMode }
      bind -T paneMode n { select-pane -L ; switch-client -T paneMode }
      bind -T paneMode e { select-pane -D ; switch-client -T paneMode }
      bind -T paneMode i { select-pane -U ; switch-client -T paneMode }
      bind -T paneMode o { select-pane -R ; switch-client -T paneMode }

      # ---- tab (window) mode (Ctrl-t) -----------------------------------
      bind -n C-t if-shell "$is_autolocked" "send-keys C-t" "switch-client -T tabMode"
      bind -T tabMode Escape switch-client -T root
      bind -T tabMode Enter  switch-client -T root
      bind -T tabMode C-t    switch-client -T root
      bind -T tabMode h { new-window -c "#{pane_current_path}" ; switch-client -T root }
      bind -T tabMode x { kill-window ; switch-client -T root }
      bind -T tabMode r { command-prompt -p "rename window:" "rename-window '%%'" ; switch-client -T root }
      bind -T tabMode b { break-pane ; switch-client -T root }
      bind -T tabMode "[" { break-pane ; swap-window -t -1 ; switch-client -T root }
      bind -T tabMode "]" { break-pane ; swap-window -t +1 ; switch-client -T root }
      bind -T tabMode Tab { last-window ; switch-client -T root }
      bind -T tabMode s { set -w synchronize-panes ; switch-client -T root }
      bind -T tabMode 1 { select-window -t :1 ; switch-client -T root }
      bind -T tabMode 2 { select-window -t :2 ; switch-client -T root }
      bind -T tabMode 3 { select-window -t :3 ; switch-client -T root }
      bind -T tabMode 4 { select-window -t :4 ; switch-client -T root }
      bind -T tabMode 5 { select-window -t :5 ; switch-client -T root }
      bind -T tabMode 6 { select-window -t :6 ; switch-client -T root }
      bind -T tabMode 7 { select-window -t :7 ; switch-client -T root }
      bind -T tabMode 8 { select-window -t :8 ; switch-client -T root }
      bind -T tabMode 9 { select-window -t :9 ; switch-client -T root }
      bind -T tabMode Left  { previous-window ; switch-client -T tabMode }
      bind -T tabMode Right { next-window     ; switch-client -T tabMode }
      bind -T tabMode Up    { previous-window ; switch-client -T tabMode }
      bind -T tabMode Down  { next-window     ; switch-client -T tabMode }
      bind -T tabMode n { previous-window ; switch-client -T tabMode }
      bind -T tabMode p { previous-window ; switch-client -T tabMode }
      bind -T tabMode i { previous-window ; switch-client -T tabMode }
      bind -T tabMode k { previous-window ; switch-client -T tabMode }
      bind -T tabMode e { next-window ; switch-client -T tabMode }
      bind -T tabMode j { next-window ; switch-client -T tabMode }
      bind -T tabMode o { next-window ; switch-client -T tabMode }
      bind -T tabMode l { next-window ; switch-client -T tabMode }

      # ---- scroll mode (Ctrl-s) — drops into tmux copy-mode -------------
      bind -n C-s if-shell "$is_autolocked" "send-keys C-s" "copy-mode"
      # inside copy-mode-vi keep zellij muscle memory:
      bind -T copy-mode-vi u send-keys -X halfpage-up
      bind -T copy-mode-vi C-s send-keys -X cancel
      bind -T copy-mode-vi q   send-keys -X cancel
      # 's' inside copy-mode kicks off search (zellij scroll → entersearch)
      bind -T copy-mode-vi s   command-prompt -p "search down:" "send-keys -X search-forward '%%'"

      # ---- resize mode (Ctrl-n) -----------------------------------------
      bind -n C-n if-shell "$is_autolocked" "send-keys C-n" "switch-client -T resizeMode"
      bind -T resizeMode Escape switch-client -T root
      bind -T resizeMode Enter  switch-client -T root
      bind -T resizeMode C-n    switch-client -T root
      bind -T resizeMode "+" { resize-pane -U 2 ; switch-client -T resizeMode }
      bind -T resizeMode "=" { resize-pane -U 2 ; switch-client -T resizeMode }
      bind -T resizeMode "-" { resize-pane -D 2 ; switch-client -T resizeMode }
      bind -T resizeMode Left  { resize-pane -L 2 ; switch-client -T resizeMode }
      bind -T resizeMode Down  { resize-pane -D 2 ; switch-client -T resizeMode }
      bind -T resizeMode Up    { resize-pane -U 2 ; switch-client -T resizeMode }
      bind -T resizeMode Right { resize-pane -R 2 ; switch-client -T resizeMode }
      # increase (zellij lowercase = increase toward direction)
      bind -T resizeMode h { resize-pane -L 2 ; switch-client -T resizeMode }
      bind -T resizeMode j { resize-pane -D 2 ; switch-client -T resizeMode }
      bind -T resizeMode k { resize-pane -U 2 ; switch-client -T resizeMode }
      bind -T resizeMode l { resize-pane -R 2 ; switch-client -T resizeMode }
      bind -T resizeMode n { resize-pane -L 2 ; switch-client -T resizeMode }
      bind -T resizeMode e { resize-pane -D 2 ; switch-client -T resizeMode }
      bind -T resizeMode i { resize-pane -U 2 ; switch-client -T resizeMode }
      bind -T resizeMode o { resize-pane -R 2 ; switch-client -T resizeMode }
      # decrease (zellij uppercase = decrease toward direction)
      bind -T resizeMode H { resize-pane -R 2 ; switch-client -T resizeMode }
      bind -T resizeMode J { resize-pane -U 2 ; switch-client -T resizeMode }
      bind -T resizeMode K { resize-pane -D 2 ; switch-client -T resizeMode }
      bind -T resizeMode L { resize-pane -L 2 ; switch-client -T resizeMode }
      bind -T resizeMode N { resize-pane -R 2 ; switch-client -T resizeMode }
      bind -T resizeMode E { resize-pane -U 2 ; switch-client -T resizeMode }
      bind -T resizeMode I { resize-pane -D 2 ; switch-client -T resizeMode }
      bind -T resizeMode O { resize-pane -L 2 ; switch-client -T resizeMode }

      # ---- move mode (Ctrl-h / Ctrl-m) — swap panes ---------------------
      bind -n C-h if-shell "$is_autolocked" "send-keys C-h" "switch-client -T moveMode"
      bind -n C-m if-shell "$is_autolocked" "send-keys C-m" "switch-client -T moveMode"
      bind -T moveMode Escape switch-client -T root
      bind -T moveMode Enter  switch-client -T root
      bind -T moveMode C-h    switch-client -T root
      bind -T moveMode C-m    switch-client -T root
      bind -T moveMode Tab { swap-pane -D ; switch-client -T moveMode }
      bind -T moveMode p   { swap-pane -U ; switch-client -T moveMode }
      bind -T moveMode Left  { swap-pane -s "{left-of}"  ; switch-client -T moveMode }
      bind -T moveMode Down  { swap-pane -s "{down-of}"  ; switch-client -T moveMode }
      bind -T moveMode Up    { swap-pane -s "{up-of}"    ; switch-client -T moveMode }
      bind -T moveMode Right { swap-pane -s "{right-of}" ; switch-client -T moveMode }
      bind -T moveMode h { swap-pane -s "{left-of}"  ; switch-client -T moveMode }
      bind -T moveMode j { swap-pane -s "{down-of}"  ; switch-client -T moveMode }
      bind -T moveMode k { swap-pane -s "{up-of}"    ; switch-client -T moveMode }
      bind -T moveMode l { swap-pane -s "{right-of}" ; switch-client -T moveMode }
      bind -T moveMode n { swap-pane -s "{left-of}"  ; switch-client -T moveMode }
      bind -T moveMode e { swap-pane -s "{down-of}"  ; switch-client -T moveMode }
      bind -T moveMode i { swap-pane -s "{up-of}"    ; switch-client -T moveMode }
      bind -T moveMode o { swap-pane -s "{right-of}" ; switch-client -T moveMode }

      # ====================================================================
      # copy-mode (vi) + wl-copy
      # ====================================================================
      bind [ copy-mode
      bind -T copy-mode-vi v send-keys -X begin-selection
      bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "${pkgs.wl-clipboard}/bin/wl-copy"
      bind -T copy-mode-vi Y send-keys -X copy-pipe-and-cancel "${pkgs.wl-clipboard}/bin/wl-copy"
      bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-no-clear "${pkgs.wl-clipboard}/bin/wl-copy"

      # mouse selection from normal mode — dbl-click = word, triple = line.
      # enter copy-mode, select, copy to wl-copy, cancel.
      bind -T root DoubleClick1Pane \
        select-pane \; \
        copy-mode -M \; \
        send-keys -X select-word \; \
        send-keys -X copy-pipe-and-cancel "${pkgs.wl-clipboard}/bin/wl-copy"
      bind -T root TripleClick1Pane \
        select-pane \; \
        copy-mode -M \; \
        send-keys -X select-line \; \
        send-keys -X copy-pipe-and-cancel "${pkgs.wl-clipboard}/bin/wl-copy"

      # click outside selection in copy-mode → cancel copy-mode (deselect).
      bind -T copy-mode-vi MouseDown1Pane select-pane \; send-keys -X cancel

      # ====================================================================
      # edit scrollback in nvim (zellij Ctrl-a v)
      # ====================================================================
      bind v run-shell ' \
        f=$(mktemp --suffix=.log); \
        tmux capture-pane -p -S -1000000 -t "#{pane_id}" > "$f"; \
        tmux new-window "${pkgs.neovim}/bin/nvim + $f"'

      # ====================================================================
      # reload
      # ====================================================================
      bind R source-file ~/.config/tmux/tmux.conf \; display "tmux reloaded"

      # ====================================================================
      # status bar (palette-driven)
      # ====================================================================
      set -g status on
      set -g status-interval 5
      set -g status-position top
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
