{
  config,
  lib,
  ...
}: let
  # Active submaps. Add more by extending this attrset.
  # icon = Material Symbols name (preferred indicator).
  # name = falls back if icon missing.
  # key  = falls back if name missing (shown as the activator label).
  submaps = {
    leader = {
      triggerKey = "SUPER, Space";
      icon = "keyboard_command_key";
      name = "leader";
      key = "Space";
      slots = [
        {
          key = "F";
          cmd = "uwsm-app -- nemo";
        }
        {
          key = "B";
          cmd = "uwsm-app -- firefox";
        }
        {
          key = "T";
          cmd = "uwsm-app -- ghostty";
        }
        {
          key = "E";
          cmd = "uwsm-app -- zeditor";
        }
        {
          key = "M";
          cmd = "uwsm-app -- thunderbird";
        }
        {
          key = "O";
          cmd = "uwsm-app -- obsidian";
        }
      ];
    };
  };

  stateFile = "$HOME/.cache/leader-hud/state";
  enter = name: "mkdir -p $HOME/.cache/leader-hud && echo ${name} > ${stateFile}";
  exit = "echo '' > ${stateFile}";

  # Submap eats only bound keys by default; everything else passes through to
  # the focused window. Enumerate alphanumerics + common punctuation and bind
  # unused ones to a no-op so the submap is truly modal.
  swallowKeys =
    (map (c: lib.toUpper c) (lib.stringToCharacters "abcdefghijklmnopqrstuvwxyz"))
    ++ (map toString (lib.range 0 9))
    ++ ["minus" "equal" "bracketleft" "bracketright" "backslash" "semicolon" "apostrophe" "grave" "comma" "period" "slash" "Tab" "space"];

  renderSubmap = name: m: let
    slotKeys = map (s: s.key) m.slots;
    noopKeys = lib.subtractLists slotKeys swallowKeys;
    slotBindings =
      lib.concatMapStringsSep "\n" (s: ''
        bind = , ${s.key}, exec, ${exit} && ${s.cmd}
        bind = , ${s.key}, submap, reset
      '')
      m.slots;
    noopBindings = lib.concatMapStringsSep "\n" (k: "bind = , ${k}, exec, true") noopKeys;
  in ''
    bind = ${m.triggerKey}, exec, ${enter name}
    bind = ${m.triggerKey}, submap, ${name}

    submap = ${name}
    ${slotBindings}
    ${noopBindings}
    bind = , Escape, exec, ${exit}
    bind = , Escape, submap, reset
    bind = , Return, exec, ${exit}
    bind = , Return, submap, reset
    submap = reset
  '';

  metadata =
    lib.mapAttrs (_: m: {inherit (m) icon name key;}) submaps;
in {
  # Submap metadata consumed by the LeaderHud DMS bar widget.
  xdg.configFile."leader-hud/submaps.json".text = builtins.toJSON metadata;

  wayland.windowManager.hyprland.extraConfig = lib.mkAfter ''
    # Leader-style submaps. Active submap surfaces as a pill in the DMS bar
    # (see ../dms-plugins/leader-hud/). Edit `submaps` in leader.nix to add slots.
    ${lib.concatStringsSep "\n\n" (lib.mapAttrsToList renderSubmap submaps)}
  '';
}
