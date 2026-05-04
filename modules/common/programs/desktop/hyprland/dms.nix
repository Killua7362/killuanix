{
  config,
  pkgs,
  ...
}: {
  programs.dank-material-shell = {
    enable = true;
  };

  programs.dank-material-shell.plugins.vmManager = {
    enable = true;
    src = ../../../../vms/vm-manager-plugin;
  };
}
