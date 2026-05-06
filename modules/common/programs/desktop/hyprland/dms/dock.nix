{
  programs.dank-material-shell.settings = {
    # ---- Dock visibility & layout ----
    showDock = false;
    dockAutoHide = false;
    dockSmartAutoHide = false;
    dockGroupByApp = false;
    dockOpenOnOverview = false;
    dockPosition = 1; # 0=Top, 1=Bottom, 2=Left, 3=Right
    dockSpacing = 4;
    dockBottomGap = 0;
    dockMargin = 0;
    dockIconSize = 40;
    dockIndicatorStyle = "circle"; # circle | bar | dot | none
    dockIsolateDisplays = false;
    dockMaxVisibleApps = 0;
    dockMaxVisibleRunningApps = 0;
    dockShowOverflowBadge = true;

    # ---- Dock border ----
    dockBorderEnabled = false;
    dockBorderColor = "surfaceText";
    dockBorderOpacity = 1;
    dockBorderThickness = 1;

    # ---- Launcher button on the dock ----
    dockLauncherEnabled = false;
    dockLauncherLogoMode = "apps";
    dockLauncherLogoCustomPath = "";
    dockLauncherLogoColorOverride = "";
    dockLauncherLogoSizeOffset = 0;
    dockLauncherLogoBrightness = 0.5;
    dockLauncherLogoContrast = 1;
  };
}
