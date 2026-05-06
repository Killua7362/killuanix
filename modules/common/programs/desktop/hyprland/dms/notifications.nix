{
  programs.dank-material-shell.settings = {
    # ---- Notification popups ----
    notificationOverlayEnabled = false;
    notificationPopupShadowEnabled = true;
    notificationPopupPrivacyMode = false;
    notificationCompactMode = false;
    notificationPopupPosition = 0; # 0=Top, etc. (SettingsData.Position enum)
    notificationAnimationSpeed = 1;
    notificationCustomAnimationDuration = 400;

    # ---- Per-urgency timeouts (ms; 0 = no auto-dismiss) ----
    notificationTimeoutLow = 5000;
    notificationTimeoutNormal = 5000;
    notificationTimeoutCritical = 0;

    # ---- Notification history ----
    notificationHistoryEnabled = true;
    notificationHistoryMaxCount = 50;
    notificationHistoryMaxAgeDays = 7;
    notificationHistorySaveLow = true;
    notificationHistorySaveNormal = true;
    notificationHistorySaveCritical = true;

    # ---- Per-app rules (filter / mute / route by app id) ----
    notificationRules = [];

    # ---- OSD (volume / brightness / mic-mute / caps-lock / etc. overlay) ----
    osdAlwaysShowValue = false;
    osdPosition = 5; # SettingsData.Position enum (5 = BottomCenter)
    osdVolumeEnabled = true;
    osdMediaVolumeEnabled = true;
    osdMediaPlaybackEnabled = false;
    osdBrightnessEnabled = true;
    osdIdleInhibitorEnabled = true;
    osdMicMuteEnabled = true;
    osdCapsLockEnabled = true;
    osdPowerProfileEnabled = true;
    osdAudioOutputEnabled = true;
  };
}
