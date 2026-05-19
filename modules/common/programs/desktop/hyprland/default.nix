{
  pkgs,
  lib,
  inputs,
  config,
  ...
}: let
  hyprlandPkg = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;

  # LeaderHud DMS plugin reads this for icon/name metadata of each submap.
  # Kept declarative on the nix side — pure data, no behavior in here.
  leaderHudMetadata = {
    leader = {
      icon = "keyboard_command_key";
      name = "leader";
      key = "Space";
    };
  };
in {
  imports = [
    ./hyprlock.nix
    ./hypridle.nix
    ./dms
    ./clipboard.nix
  ];

  # Disabled so home-manager doesn't write ~/.config/hypr/hyprland.conf.
  # Hyprland 0.55+ reads ~/.config/hypr/hyprland.lua natively (symlinked below).
  # The system-level NixOS programs.hyprland.enable still handles UWSM /
  # portals / session wiring — that stays untouched.
  wayland.windowManager.hyprland.enable = false;

  # Stable user path for the LSP-stub directory. The hyprland package's
  # share/hypr/stubs dir changes hash on each upgrade; symlinking it through
  # a fixed path lets .luarc.json reference one location forever.
  home.file.".local/share/hypr/stubs".source = "${hyprlandPkg}/share/hypr/stubs";

  # Live-edit symlink: edits to lua/*.lua in this repo take effect via
  # Hyprland's autoreload — no home-manager activation needed.
  xdg.configFile."hypr/hyprland.lua".source =
    config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/killuanix/modules/common/programs/desktop/hyprland/lua/hyprland.lua";

  # LSP config dropped next to hyprland.lua so lua-language-server picks up
  # the stubs (walks upward from the buffer file looking for .luarc.json).
  xdg.configFile."hypr/.luarc.json".text = builtins.toJSON {
    "runtime.version" = "Lua 5.4";
    "diagnostics.globals" = ["hl"];
    "workspace.library" = ["~/.local/share/hypr/stubs"];
    "workspace.checkThirdParty" = false;
    "telemetry.enable" = false;
  };

  # UWSM env injection — sources hm-session-vars.sh (incl. home.sessionPath
  # additions like ~/.local/bin) into the Hyprland session so spawned procs
  # find user binaries. Per hypr wiki: NixOS-on-Home-Manager UWSM guide.
  xdg.configFile."uwsm/env".source = "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";

  # Static metadata consumed by the LeaderHud DMS bar plugin.
  xdg.configFile."leader-hud/submaps.json".text = builtins.toJSON leaderHudMetadata;

  # Scroller column-width toggle. Was inline in keybinds.nix; the lua binds
  # invoke it by name on $PATH.
  home.packages = [
    (pkgs.writeShellScriptBin "hypr-toggle-col-width" ''
      state="''${XDG_RUNTIME_DIR:-/tmp}/hypr-colresize-dir"
      last=$(cat "$state" 2>/dev/null || echo "-")
      if [ "$last" = "+" ]; then
        dir="-"
      else
        dir="+"
      fi
      echo "$dir" > "$state"
      ${hyprlandPkg}/bin/hyprctl dispatch layoutmsg "colresize ''${dir}conf"
    '')
  ];
}
