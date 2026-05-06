{
  programs.dank-material-shell.settings = {
    # ---- Status icons shown in the control-center button on the bar ----
    controlCenterShowNetworkIcon = true;
    controlCenterShowBluetoothIcon = true;
    controlCenterShowAudioIcon = true;
    controlCenterShowAudioPercent = false;
    controlCenterShowVpnIcon = true;
    controlCenterShowBrightnessIcon = false;
    controlCenterShowBrightnessPercent = false;
    controlCenterShowMicIcon = false;
    controlCenterShowMicPercent = true;
    controlCenterShowBatteryIcon = false;
    controlCenterShowPrinterIcon = false;
    controlCenterShowScreenSharingIcon = true;

    # ---- Privacy indicator on the bar ----
    showPrivacyButton = true;
    privacyShowMicIcon = false;
    privacyShowCameraIcon = false;
    privacyShowScreenShareIcon = false;

    # ---- Tiles / sliders inside the control center popup ----
    # `width` is a percentage of the row (50 = half width).
    controlCenterWidgets = [
      {
        id = "volumeSlider";
        enabled = true;
        width = 50;
      }
      {
        id = "brightnessSlider";
        enabled = true;
        width = 50;
      }
      {
        id = "wifi";
        enabled = true;
        width = 50;
      }
      {
        id = "bluetooth";
        enabled = true;
        width = 50;
      }
      {
        id = "audioOutput";
        enabled = true;
        width = 50;
      }
      {
        id = "audioInput";
        enabled = true;
        width = 50;
      }
      {
        id = "nightMode";
        enabled = true;
        width = 50;
      }
      {
        id = "darkMode";
        enabled = true;
        width = 50;
      }
    ];
  };
}
