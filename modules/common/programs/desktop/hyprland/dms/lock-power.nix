{
  programs.dank-material-shell.settings = {
    # ---- Lock screen layout / widgets ----
    lockScreenShowPowerActions = true;
    lockScreenShowSystemIcons = true;
    lockScreenShowTime = true;
    lockScreenShowDate = true;
    lockScreenShowProfileImage = true;
    lockScreenShowPasswordField = true;
    lockScreenShowMediaPlayer = true;
    lockScreenPowerOffMonitorsOnLock = false;
    lockScreenActiveMonitor = "all"; # "all" | monitor name
    lockScreenInactiveColor = "#000000";
    lockScreenNotificationMode = 0;
    lockAtStartup = false;
    hideBrightnessSlider = false;

    # ---- Auth methods on lock screen ----
    enableFprint = false;
    maxFprintTries = 15;
    enableU2f = false;
    u2fMode = "or"; # "or" = u2f OR password, "and" = both required

    # ---- Idle / fade-to-lock ----
    lockBeforeSuspend = false;
    loginctlLockIntegration = true;
    fadeToLockEnabled = true;
    fadeToLockGracePeriod = 5;
    fadeToDpmsEnabled = true;
    fadeToDpmsGracePeriod = 5;

    # ---- Power profile timeouts (seconds; 0 = disabled) ----
    acMonitorTimeout = 0;
    acLockTimeout = 0;
    acSuspendTimeout = 0;
    acSuspendBehavior = 0; # SettingsData.SuspendBehavior enum
    acProfileName = "";
    batteryMonitorTimeout = 0;
    batteryLockTimeout = 0;
    batterySuspendTimeout = 0;
    batterySuspendBehavior = 0;
    batteryProfileName = "";
    batteryChargeLimit = 100;

    # ---- Power menu ----
    powerActionConfirm = true;
    powerActionHoldDuration = 0.5;
    powerMenuActions = [
      "reboot"
      "logout"
      "poweroff"
      "lock"
      "suspend"
      "restart"
    ];
    powerMenuDefaultAction = "logout";
    powerMenuGridLayout = false;
    customPowerActionLock = "";
    customPowerActionLogout = "";
    customPowerActionSuspend = "";
    customPowerActionHibernate = "";
    customPowerActionReboot = "";
    customPowerActionPowerOff = "";

    # ---- System updater widget ----
    updaterHideWidget = false;
    updaterUseCustomCommand = false;
    updaterCustomCommand = "";
    updaterTerminalAdditionalParams = "";
  };
}
