{hostName ? null, ...}: {
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
    # Lock (via DMS, gated by loginctlLockIntegration below) before the system
    # suspends, so any suspend sleeps locked — including chrollo's power-button
    # short press (HandlePowerKey=suspend, chrollo/power.nix). SessionService
    # registers this with the DMS backend as a delay inhibitor on PrepareForSleep.
    lockBeforeSuspend = true;
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
    # Auto-switch profile on charger plug/unplug (DMS BatteryService
    # onIsPluggedInChanged). Enum: ""=don't change, "0"=power-saver,
    # "1"=balanced, "2"=performance. Only fires on the AC-state *event*, so a
    # manual pick in the battery popout persists until the next plug/unplug.
    # chrollo only (laptop); killua keeps "" so its handheld power tooling
    # (hhd/TDP) stays the sole profile authority.
    acProfileName =
      if hostName == "chrollo"
      then "2" # performance on AC
      else "";
    batteryMonitorTimeout = 0;
    batteryLockTimeout = 0;
    batterySuspendTimeout = 0;
    batterySuspendBehavior = 0;
    batteryProfileName =
      if hostName == "chrollo"
      then "1" # balanced on battery
      else "";
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
