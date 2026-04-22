{
  config,
  pkgs,
  lib,
  ...
}: let
  sopsFile = ../../../../secrets/personal.yaml;

  # Parse `clipboard:` block keys out of the sops yaml. Keys are plaintext —
  # only the values after `ENC[...]` are encrypted — so a simple line scan works.
  # Scanning state: before `clipboard:` → skip; after → collect 4-space-indented
  # `key:` lines until we hit an unindented line (next top-level entry).
  clipboardKeys = let
    lines = lib.splitString "\n" (builtins.readFile sopsFile);
    step = acc: line:
      if acc.done
      then acc
      else if acc.inside
      then
        if line == "" || lib.hasPrefix "    " line
        then let
          m = builtins.match "    ([a-zA-Z_][a-zA-Z0-9_-]*):.*" line;
        in
          if m != null
          then acc // {keys = acc.keys ++ [(builtins.head m)];}
          else acc
        else acc // {done = true;}
      else if line == "clipboard:"
      then acc // {inside = true;}
      else acc;
    result =
      builtins.foldl' step {
        keys = [];
        inside = false;
        done = false;
      }
      lines;
  in
    result.keys;

  # Title-case each underscore-separated word: github_token -> "Github Token".
  titleCase = s: let
    cap = w:
      if w == ""
      then ""
      else lib.toUpper (builtins.substring 0 1 w) + builtins.substring 1 (builtins.stringLength w) w;
  in
    lib.concatMapStringsSep " " cap (lib.splitString "_" s);

  # Display label -> sops secret path.
  entries = lib.listToAttrs (map (k:
    lib.nameValuePair (titleCase k) "clipboard/${k}")
  clipboardKeys);

  p = config.theme.palette;

  wofiConfig = pkgs.writeText "clipboard-menu-wofi.conf" ''
    width=340
    height=320
    location=center
    prompt=Clipboard
    insensitive=true
    allow_markup=true
    hide_scroll=true
    no_actions=true
    gtk_dark=true
    layer=overlay
    key_forward=Down,Ctrl-n
    key_backward=Up,Ctrl-p
  '';

  wofiStyle = pkgs.writeText "clipboard-menu-wofi.css" ''
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

  clipboardMenu = pkgs.writeShellApplication {
    name = "clipboard-menu";
    runtimeInputs = with pkgs; [wofi wl-clipboard wtype libnotify coreutils];
    text = ''
      declare -A secrets=(
        ${lib.concatStringsSep "\n        " (lib.mapAttrsToList
        (name: path: "[${lib.escapeShellArg name}]=${lib.escapeShellArg config.sops.secrets.${path}.path}")
        entries)}
      )

      if [ ''${#secrets[@]} -eq 0 ]; then
        notify-send -u critical 'Clipboard' 'No clipboard entries configured'
        exit 1
      fi

      choice=$(printf '%s\n' "''${!secrets[@]}" | sort | wofi \
        --dmenu \
        --conf ${wofiConfig} \
        --style ${wofiStyle})
      [ -z "$choice" ] && exit 0

      file=''${secrets[$choice]:-}
      if [ -z "$file" ] || [ ! -r "$file" ]; then
        notify-send -u critical 'Clipboard' "Secret unavailable: $choice"
        exit 1
      fi

      wl-copy --trim-newline < "$file"
      sleep 0.05
      wtype -M ctrl v -m ctrl || true
    '';
  };
in
  lib.mkIf pkgs.stdenv.isLinux {
    sops.secrets = lib.mapAttrs' (_: path: lib.nameValuePair path {}) entries;
    home.packages = [clipboardMenu];
  }
