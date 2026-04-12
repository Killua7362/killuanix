{
  pkgs,
  config,
  ...
}: {
  xdg.configFile = {
    "/home/killua/.lesskey" = {
      source = config.lib.file.mkOutOfStoreSymlink /home/killua/killuanix/DotFiles/macnix/.lesskey;
    };
  };
}
