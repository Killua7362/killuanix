{
  pkgs,
  config,
  ...
}: {
  xdg.configFile = {
    "/home/killua/.lesskey" = {
      source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/macnix/.lesskey;
    };
    "yazi" = {
      source = config.lib.file.mkOutOfStoreSymlink /Users/killua/killuanix/DotFiles/yazi;
      recursive = true;
    };
    "lazygit.yml" = {
      source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/lazygit.yml;
    };
  };
}
