{
  programs.dank-material-shell.settings = {
    # ---- Theme & matugen ----
    currentThemeName = "dynamic";
    currentThemeCategory = "dynamic";
    customThemeFile = "";
    registryThemeVariants = {};
    matugenScheme = "scheme-content";
    runUserMatugenTemplates = true;
    matugenTargetMonitor = "";

    # ---- Colors / transparency / shape ----
    popupTransparency = 1;
    dockTransparency = 1;
    widgetBackgroundColor = "sch";
    widgetColorMode = "default";
    controlCenterTileColorMode = "primary";
    buttonColorMode = "primary";
    cornerRadius = 12;

    # ---- Per-compositor layout overrides (-1 = use compositor default) ----
    niriLayoutGapsOverride = -1;
    niriLayoutRadiusOverride = -1;
    niriLayoutBorderSize = -1;
    hyprlandLayoutGapsOverride = -1;
    hyprlandLayoutRadiusOverride = -1;
    hyprlandLayoutBorderSize = -1;
    mangoLayoutGapsOverride = -1;
    mangoLayoutRadiusOverride = -1;
    mangoLayoutBorderSize = -1;

    # ---- Animations ----
    animationSpeed = 1;
    customAnimationDuration = 500;
    syncComponentAnimationSpeeds = true;
    popoutAnimationSpeed = 1;
    popoutCustomAnimationDuration = 150;
    modalAnimationSpeed = 1;
    modalCustomAnimationDuration = 150;
    enableRippleEffects = true;
    modalDarkenBackground = true;

    # ---- Wallpaper visuals ----
    wallpaperFillMode = "Fill";
    blurredWallpaperLayer = false;
    blurWallpaperOnOverview = false;

    # ---- Night mode (toggle only; schedule lives in `session`) ----
    nightModeEnabled = false;
  };
}
