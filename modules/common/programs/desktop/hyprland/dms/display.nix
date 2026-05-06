{
  programs.dank-material-shell.settings = {
    # ---- Display naming / per-monitor preferences ----
    displayNameMode = "system"; # system | model | port | custom
    screenPreferences = {};
    showOnLastDisplay = {};
    niriOutputSettings = {};
    hyprlandOutputSettings = {};

    # ---- Saved display profiles (docked / undocked / etc.) ----
    displayProfiles = {};
    activeDisplayProfile = {};
    displayProfileAutoSelect = false;
    displayShowDisconnected = false;
    displaySnapToEdge = true;

    # ---- Desktop-clock floating widget ----
    desktopClockEnabled = false;
    desktopClockStyle = "analog"; # analog | digital
    desktopClockTransparency = 0.8;
    desktopClockColorMode = "primary";
    desktopClockCustomColor = {
      r = 1;
      g = 1;
      b = 1;
      a = 1;
      hsvHue = -1;
      hsvSaturation = 0;
      hsvValue = 1;
      hslHue = -1;
      hslSaturation = 0;
      hslLightness = 1;
      valid = true;
    };
    desktopClockShowDate = true;
    desktopClockShowAnalogNumbers = false;
    desktopClockShowAnalogSeconds = true;
    desktopClockX = -1; # -1 = auto-position
    desktopClockY = -1;
    desktopClockWidth = 280;
    desktopClockHeight = 180;
    desktopClockDisplayPreferences = ["all"];

    # ---- System-monitor floating widget ----
    systemMonitorEnabled = false;
    systemMonitorShowHeader = true;
    systemMonitorTransparency = 0.8;
    systemMonitorColorMode = "primary";
    systemMonitorCustomColor = {
      r = 1;
      g = 1;
      b = 1;
      a = 1;
      hsvHue = -1;
      hsvSaturation = 0;
      hsvValue = 1;
      hslHue = -1;
      hslSaturation = 0;
      hslLightness = 1;
      valid = true;
    };
    systemMonitorShowCpu = true;
    systemMonitorShowCpuGraph = true;
    systemMonitorShowCpuTemp = true;
    systemMonitorShowGpuTemp = false;
    systemMonitorGpuPciId = "";
    systemMonitorShowMemory = true;
    systemMonitorShowMemoryGraph = true;
    systemMonitorShowNetwork = true;
    systemMonitorShowNetworkGraph = true;
    systemMonitorShowDisk = true;
    systemMonitorShowTopProcesses = false;
    systemMonitorTopProcessCount = 3;
    systemMonitorTopProcessSortBy = "cpu"; # cpu | memory
    systemMonitorGraphInterval = 60;
    systemMonitorLayoutMode = "auto";
    systemMonitorX = -1;
    systemMonitorY = -1;
    systemMonitorWidth = 320;
    systemMonitorHeight = 480;
    systemMonitorDisplayPreferences = ["all"];
    systemMonitorVariants = [];

    # ---- Desktop widget framework (positions / grids / instances / groups) ----
    desktopWidgetPositions = {};
    desktopWidgetGridSettings = {};
    desktopWidgetInstances = [];
    desktopWidgetGroups = [];
  };
}
