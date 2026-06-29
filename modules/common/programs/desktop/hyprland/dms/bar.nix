{
  programs.dank-material-shell.settings = {
    # ---- Top-bar widget visibility (left/center/right placement is in barConfigs below) ----
    showLauncherButton = true;
    showWorkspaceSwitcher = true;
    showFocusedWindow = true;
    showWeather = true;
    showMusic = true;
    showClipboard = true;
    showCpuUsage = true;
    showMemUsage = true;
    showCpuTemp = true;
    showGpuTemp = true;
    showSystemTray = true;
    showClock = true;
    showNotificationButton = true;
    showBattery = true;
    showControlCenterButton = true;
    showCapsLockIndicator = true;

    # ---- Bar widget compact modes / behavior ----
    clockCompactMode = false;
    focusedWindowCompactMode = false;
    runningAppsCompactMode = true;
    keyboardLayoutNameCompactMode = false;
    runningAppsCurrentWorkspace = true;
    runningAppsGroupByApp = false;
    runningAppsCurrentMonitor = false;
    appIdSubstitutions = [];
    centeringMode = "index";
    barMaxVisibleApps = 0;
    barMaxVisibleRunningApps = 0;
    barShowOverflowBadge = true;

    # ---- Apps-on-bar (running apps shown as dock-style icons) ----
    appsDockHideIndicators = false;
    appsDockColorizeActive = false;
    appsDockActiveColorMode = "primary";
    appsDockEnlargeOnHover = false;
    appsDockEnlargePercentage = 125;
    appsDockIconSizePercentage = 100;

    # ---- Music widget visuals ----
    waveProgressEnabled = true;
    scrollTitleEnabled = true;
    audioVisualizerEnabled = true;
    audioScrollMode = "volume";
    audioWheelScrollAmount = 5;
    mediaSize = 1;

    # ---- Workspace switcher widget ----
    showWorkspaceIndex = false;
    showWorkspaceName = false;
    showWorkspacePadding = false;
    workspaceScrolling = false;
    showWorkspaceApps = true;
    workspaceDragReorder = true;
    maxWorkspaceIcons = 3;
    workspaceAppIconSizeOffset = 0;
    groupWorkspaceApps = true;
    workspaceFollowFocus = false;
    showOccupiedWorkspacesOnly = false;
    reverseScrolling = false;
    dwlShowAllTags = false;
    workspaceColorMode = "default";
    workspaceOccupiedColorMode = "none";
    workspaceUnfocusedColorMode = "default";
    workspaceUrgentColorMode = "default";
    workspaceFocusedBorderEnabled = false;
    workspaceFocusedBorderColor = "primary";
    workspaceFocusedBorderThickness = 2;
    workspaceNameIcons = {};

    # ---- Bar instances (one bar per entry; per-bar layout/style/behavior) ----
    barConfigs = [
      {
        id = "default";
        name = "Main Bar";
        enabled = true;
        position = 0;
        screenPreferences = ["all"];
        showOnLastDisplay = true;
        leftWidgets = [
          "launcherButton"
          "workspaceSwitcher"
          "focusedWindow"
          {
            id = "activitySim";
            enabled = true;
          }
        ];
        centerWidgets = [
          "clock"
        ];
        rightWidgets = [
          {
            id = "leaderHud";
            enabled = true;
          }
          {
            id = "dankActions:variant_wvkbd";
            enabled = true;
          }
          "systemTray"
          "clipboard"
          "cpuUsage"
          "memUsage"
          "notificationButton"
          "battery"
          "controlCenterButton"
        ];
        spacing = 4;
        innerPadding = 4;
        bottomGap = 0;
        transparency = 1;
        widgetTransparency = 1;
        squareCorners = false;
        noBackground = false;
        maximizeWidgetIcons = false;
        maximizeWidgetText = false;
        removeWidgetPadding = false;
        widgetPadding = 8;
        gothCornersEnabled = false;
        gothCornerRadiusOverride = false;
        gothCornerRadiusValue = 12;
        borderEnabled = false;
        borderColor = "surfaceText";
        borderOpacity = 1;
        borderThickness = 1;
        widgetOutlineEnabled = false;
        widgetOutlineColor = "primary";
        widgetOutlineOpacity = 1;
        widgetOutlineThickness = 1;
        fontScale = 1;
        iconScale = 1;
        autoHide = false;
        autoHideDelay = 250;
        showOnWindowsOpen = false;
        openOnOverview = false;
        visible = true;
        popupGapsAuto = true;
        popupGapsManual = 4;
        maximizeDetection = true;
        scrollEnabled = true;
        scrollXBehavior = "column";
        scrollYBehavior = "workspace";
        shadowIntensity = 0;
        shadowOpacity = 60;
        shadowColorMode = "text";
        shadowCustomColor = "#000000";
        clickThrough = false;
      }
    ];

    # dankBarFontScale = 1.0; # extra global font scale for bar widgets
  };
}
