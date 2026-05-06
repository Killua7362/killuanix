{
  programs.dank-material-shell.settings = {
    # ---- Launcher button logo (top-bar / dock) ----
    launcherLogoMode = "apps"; # apps | distro | custom
    launcherLogoCustomPath = "";
    launcherLogoColorOverride = "";
    launcherLogoColorInvertOnMode = false;
    launcherLogoBrightness = 0.5;
    launcherLogoContrast = 1;
    launcherLogoSizeOffset = 0;

    # ---- DankLauncher v2 ----
    dankLauncherV2Size = "compact"; # compact | normal | large
    dankLauncherV2BorderEnabled = false;
    dankLauncherV2BorderThickness = 2;
    dankLauncherV2BorderColor = "primary";
    dankLauncherV2ShowFooter = true;
    dankLauncherV2UnloadOnClose = false;

    # ---- View modes for launcher / spotlight / pickers ----
    appLauncherViewMode = "list"; # list | grid
    spotlightModalViewMode = "list";
    browserPickerViewMode = "grid";
    appPickerViewMode = "grid";
    sortAppsAlphabetically = false;
    appLauncherGridColumns = 4;
    spotlightCloseNiriOverview = true;

    # ---- Per-section view-mode overrides (keyed by section id) ----
    spotlightSectionViewModes = {};
    appDrawerSectionViewModes = {};

    # ---- Launcher usage history (auto-populated at runtime) ----
    browserUsageHistory = {};
    filePickerUsageHistory = {};

    # ---- Niri overview overlay ----
    niriOverviewOverlayEnabled = true;
    # overviewRows = 2;
    # overviewColumns = 5;
    # overviewScale = 0.16;
  };
}
