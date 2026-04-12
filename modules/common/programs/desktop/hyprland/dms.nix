{
  config,
  pkgs,
  ...
}: {
  programs.dank-material-shell = {
    enable = true;
  };

  programs.dankMaterialShell.plugins.vmManager = {
    enable = true;
    src = ../../../../vms/vm-manager-plugin;
  };
}
