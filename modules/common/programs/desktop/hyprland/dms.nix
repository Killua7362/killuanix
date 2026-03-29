{
  config,
  pkgs,
  ...
}: {
  programs.dank-material-shell = {
    enable = true;
  };

  programs.dankMaterialShell.plugins.activitySim = {
    enable = true;
    src = ../../../../vms/activity-sim-plugin;
  };
}
