{
  config,
  pkgs,
  lib,
  ...
}: let
  p = config.theme.palette;

  # Same theme as clipboard-menu, but taller + allow_images so image entries
  # render as thumbnails. Backed by cliphist (see hyprland/clipboard.nix watchers).
  wofiConfig = pkgs.writeText "clipboard-history-wofi.conf" ''
    width=460
    height=520
    location=center
    prompt=Clipboard History
    insensitive=true
    allow_markup=true
    allow_images=true
    hide_scroll=true
    no_actions=true
    gtk_dark=true
    layer=overlay
    key_forward=Down,Ctrl-n
    key_backward=Up,Ctrl-p
  '';

  wofiStyle = pkgs.writeText "clipboard-history-wofi.css" ''
    * {
      font-family: "JetBrainsMono Nerd Font", monospace;
      font-size: 15px;
      transition: none;
      animation: none;
    }

    window {
      background-color: ${p.bg};
      border: 1px solid ${p.color8};
      border-radius: 0;
      padding: 10px;
    }

    #outer-box {
      background-color: transparent;
      padding: 0;
    }

    #input {
      background-color: ${p.color8};
      color: ${p.fg};
      border: 1px solid ${p.color0};
      border-radius: 0;
      padding: 8px 10px;
      margin: 0 0 8px 0;
      caret-color: ${p.color4};
    }

    #input:focus {
      border-color: ${p.color4};
      outline: none;
    }

    #input image {
      color: ${p.color4};
    }

    #inner-box,
    #scroll {
      background-color: transparent;
      margin: 0;
      padding: 0;
    }

    #text {
      color: ${p.fg};
      padding: 2px 4px;
    }

    #img {
      margin-right: 8px;
    }

    #entry {
      background-color: transparent;
      border: none;
      border-radius: 0;
      padding: 6px 10px;
      margin: 1px 0;
    }

    #entry:selected {
      background-color: ${p.selection_bg};
    }

    #entry:selected #text {
      color: ${p.selection_fg};
      font-weight: 600;
    }
  '';

  clipboardHistory = pkgs.writeShellApplication {
    name = "clipboard-history";
    runtimeInputs = with pkgs; [cliphist wofi wl-clipboard coreutils gnugrep];
    text = ''
      tmp=$(mktemp -d)
      trap 'rm -rf "$tmp"' EXIT

      # Cap the picker list for a fast open. cliphist's own store is capped at 750
      # (its default -max-items); this only limits how many the wofi list shows.
      # `clipboard-history --all` skips the cap to browse/search the whole store.
      limit=100
      if [ "''${1:-}" = "--all" ]; then
        raw=$(cliphist list || true)
      else
        raw=$(cliphist list | head -n "$limit" || true)
      fi
      [ -z "$raw" ] && exit 0

      # Build the wofi list. Image entries are decoded to a temp thumbnail and
      # rendered via wofi's `img:PATH:text:LABEL` markup (label = cliphist id, so
      # selecting one returns just the id). Text entries pass through verbatim,
      # keeping their leading `<id>\t` prefix that cliphist decode reads.
      menu=$(printf '%s\n' "$raw" | while IFS= read -r line; do
        id=''${line%%$'\t'*}
        content=''${line#*$'\t'}
        if printf '%s' "$content" | grep -qiE '\[\[ ?binary data .*(png|jpe?g|bmp|gif|webp)'; then
          if printf '%s\t' "$id" | cliphist decode > "$tmp/$id.img" 2>/dev/null; then
            printf 'img:%s:text:%s\n' "$tmp/$id.img" "$id"
            continue
          fi
        fi
        printf '%s\n' "$line"
      done)

      [ -z "$menu" ] && exit 0

      choice=$(printf '%s\n' "$menu" | wofi \
        --dmenu \
        --conf ${wofiConfig} \
        --style ${wofiStyle})
      [ -z "$choice" ] && exit 0

      # Recover the cliphist id from whatever wofi returned:
      #   text entry      -> "<id>\t<preview>"      (id before the tab)
      #   img entry label -> "<id>"                 (bare)
      #   img entry markup -> "img:/path:text:<id>" (id after the last :text:)
      case "$choice" in
        *"$(printf '\t')"*) id=''${choice%%$'\t'*} ;;
        img:*) id=''${choice##*:text:} ;;
        *) id=$choice ;;
      esac
      # cliphist decode parses the id up to the first tab, so terminate with one
      # (a bare id fails: "converting id: strconv.Atoi ... invalid syntax").
      printf '%s\t' "$id" | cliphist decode | wl-copy
    '';
  };
in
  lib.mkIf pkgs.stdenv.isLinux {
    home.packages = [clipboardHistory];
  }
