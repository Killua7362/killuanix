{
  pkgs,
  config,
  ...
}: {
  xdg.configFile = {
    "/Users/killua/.config/karabiner.edn" = {
      source = config.lib.file.mkOutOfStoreSymlink /Users/killua/killuanix/DotFiles/macnix/karabiner/karabiner.edn;
    };
    "/Users/killua/.config/yabai" = {
      source = config.lib.file.mkOutOfStoreSymlink /Users/killua/killuanix/DotFiles/macnix/yabai;
      recursive = true;
    };
    "/Users/killua/.config/skhd" = {
      source = config.lib.file.mkOutOfStoreSymlink /Users/killua/killuanix/DotFiles/macnix/skhd;
      recursive = true;
    };
    "/Users/killua/.config/borders" = {
      source = config.lib.file.mkOutOfStoreSymlink /Users/killua/killuanix/DotFiles/macnix/borders;
      recursive = true;
    };
    "/Users/killua/.aerospace.toml" = {
      source = config.lib.file.mkOutOfStoreSymlink /Users/killua/killuanix/DotFiles/macnix/.aerospace.toml;
      recursive = true;
    };
  };
}
