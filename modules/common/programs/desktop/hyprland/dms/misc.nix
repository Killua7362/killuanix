{
  programs.dank-material-shell.settings = {
    # ---- Time / date / weather units ----
    use24HourClock = false;
    showSeconds = false;
    padHours12Hour = false;
    useFahrenheit = false;
    windSpeedUnit = "kmh"; # kmh | mph | ms | knots
    weatherEnabled = true;
    useAutoLocation = false;
    weatherLocation = "Sirsi, 581401";
    weatherCoordinates = "14.6192362,74.8388611";
    clockDateFormat = ""; # "" = locale default
    lockDateFormat = "";

    # ---- Network preference ----
    networkPreference = "wifi"; # auto | wifi | wired

    # ---- Persisted user-launch prefix (e.g. firejail / box) ----
    launchPrefix = "uwsm-app -- ";

    # ---- Clipboard popup ----
    clipboardEnterToPaste = false;

    # ---- GPU monitor target ----
    selectedGpuIndex = 0;
    enabledGpuPciIds = [];

    # ---- Pinned device rules (DMS remembers per-device tweaks) ----
    brightnessDevicePins = {};
    wifiNetworkPins = {};
    bluetoothDevicePins = {};
    audioInputDevicePins = {};
    audioOutputDevicePins = {};

    # ---- Plugins ----
    builtInPluginSettings = {};
    launcherPluginVisibility = {};
    launcherPluginOrder = [];

    # ---- Settings schema version (DMS migrates older formats forward) ----
    configVersion = 5;
  };
}
