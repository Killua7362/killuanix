{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./theme.nix
    ./bar.nix
    ./control-center.nix
    ./dock.nix
    ./launcher.nix
    ./greeter.nix
    ./notifications.nix
    ./lock-power.nix
    ./theming-templates.nix
    ./fonts-sounds.nix
    ./display.nix
    ./misc.nix
  ];

  programs.dank-material-shell = {
    enable = true;

    # ---- Module-level options (commented = upstream defaults; uncomment to override) ----
    # Source: ${dms}/distro/nix/options.nix and ${dms}/distro/nix/home.nix
    # systemd = {
    #   enable = false; # we launch dms via UWSM exec-once in execs.nix; keep off
    #   restartIfChanged = true;
    #   target = config.wayland.systemd.target;
    # };
    # dgop.package = pkgs.dgop;
    # quickshell.package = inputs.dms.packages.${pkgs.system}.quickshell; # default: built from DMS source
    # enableSystemMonitoring = true;
    # enableVPN = true;
    # enableDynamicTheming = true;
    # enableAudioWavelength = true;
    # enableCalendarEvents = true;
    # enableClipboardPaste = true;
    # managePluginSettings = true; # auto-true when any plugin sets `settings = { ... }`

    # ---- Clipboard daemon config (~/.config/DankMaterialShell/clsettings.json) ----
    # Source: ${dms}/core/internal/server/clipboard/types.go (Config + DefaultConfig)
    # Only written when non-empty; values shown are upstream defaults.
    # clipboardSettings = {
    #   maxHistory = 100;
    #   maxEntrySize = 5242880; # 5 MiB
    #   autoClearDays = 0; # 0 = never
    #   clearAtStartup = false;
    #   disabled = false;
    #   maxPinned = 25;
    # };

    # ---- Session state (~/.local/state/DankMaterialShell/session.json) ----
    # Source: ${dms}/quickshell/Common/SessionData.qml. Most fields are runtime UI
    # state and are rarely worth pinning; weather/night-mode/wallpaper paths are
    # the typical exceptions. Only set the keys you actually want managed.
    # session = {
    #   isLightMode = false;
    #   doNotDisturb = false;
    #
    #   # Wallpaper
    #   wallpaperPath = "";
    #   perMonitorWallpaper = false;
    #   monitorWallpapers = {};
    #   perModeWallpaper = false;
    #   wallpaperPathLight = "";
    #   wallpaperPathDark = "";
    #   monitorWallpapersLight = {};
    #   monitorWallpapersDark = {};
    #   monitorWallpaperFillModes = {};
    #   wallpaperTransition = "fade"; # none|fade|wipe|disc|stripes|"iris bloom"|pixelate|portal
    #   includedTransitions = ["fade" "wipe" "disc" "stripes" "iris bloom" "pixelate" "portal"];
    #   wallpaperCyclingEnabled = false;
    #   wallpaperCyclingMode = "interval";
    #   wallpaperCyclingInterval = 300;
    #   wallpaperCyclingTime = "06:00";
    #   monitorCyclingSettings = {};
    #
    #   # Night mode
    #   nightModeEnabled = false;
    #   nightModeTemperature = 4500;
    #   nightModeHighTemperature = 6500;
    #   nightModeAutoEnabled = false;
    #   nightModeAutoMode = "time"; # time|location
    #   nightModeStartHour = 18;
    #   nightModeStartMinute = 0;
    #   nightModeEndHour = 6;
    #   nightModeEndMinute = 0;
    #   latitude = 0.0;
    #   longitude = 0.0;
    #   nightModeUseIPLocation = false;
    #   nightModeLocationProvider = "";
    #
    #   # Auto theme mode (light/dark schedule)
    #   themeModeAutoEnabled = false;
    #   themeModeAutoMode = "time";
    #   themeModeStartHour = 18;
    #   themeModeStartMinute = 0;
    #   themeModeEndHour = 6;
    #   themeModeEndMinute = 0;
    #   themeModeShareGammaSettings = true;
    #
    #   # Misc state
    #   pinnedApps = [];
    #   barPinnedApps = [];
    #   dockLauncherPosition = 0;
    #   hiddenTrayIds = [];
    #   trayItemOrder = [];
    #   recentColors = [];
    #   showThirdPartyPlugins = false;
    #   launchPrefix = "";
    #
    #   # Brightness / GPU
    #   lastBrightnessDevice = "";
    #   brightnessExponentialDevices = {};
    #   brightnessUserSetValues = {};
    #   brightnessExponentValues = {};
    #   selectedGpuIndex = 0;
    #   nvidiaGpuTempEnabled = false;
    #   nonNvidiaGpuTempEnabled = false;
    #   enabledGpuPciIds = [];
    #
    #   # Network / weather
    #   wifiDeviceOverride = "";
    #   weatherHourlyDetailed = true;
    #   weatherLocation = "New York, NY";
    #   weatherCoordinates = "40.7128,-74.0060";
    #
    #   # Apps / launcher
    #   hiddenApps = [];
    #   appOverrides = {};
    #   searchAppActions = true;
    #   launcherLastMode = "all";
    #   appDrawerLastMode = "apps";
    #   niriOverviewLastMode = "apps";
    #
    #   # VPN / audio device pins
    #   vpnLastConnected = "";
    #   deviceMaxVolumes = {};
    #   hiddenOutputDeviceNames = [];
    #   hiddenInputDeviceNames = [];
    #
    #   configVersion = 3;
    # };
  };

  # Plugin schema:
  #   programs.dank-material-shell.plugins.<name> = {
  #     enable = true;            # default true
  #     src = <package or path>;  # required
  #     settings = { ... };       # optional; written when managePluginSettings is on
  #   };
  # Example (from upstream README):
  # programs.dank-material-shell.plugins.DockerManager = {
  #   src = pkgs.fetchFromGitHub {
  #     owner = "LuckShiba";
  #     repo = "DmsDockerManager";
  #     rev = "v1.2.0";
  #     sha256 = "sha256-VoJCaygWnKpv0s0pqTOmzZnPM922qPDMHk4EPcgVnaU=";
  #   };
  # };
  programs.dank-material-shell.plugins.leaderHud = {
    enable = true;
    src = ../../qml/leader-hud;
  };

  # Upstream community/first-party plugins now come from the dms-plugin-registry
  # homeModule (flake input `dms-plugin-registry`), which registers every plugin
  # in the registry disabled-by-default and supplies `src` (daily-updated pin in
  # our flake.lock). We just flip `.enable` and add `settings`. No manual
  # fetchFromGitHub rev/sha to bump anymore — `nix flake update dms-plugin-registry`
  # bumps all of them at once. (leaderHud above stays local — not in the registry.)
  programs.dank-material-shell.plugins.dankActions = {
    enable = true;
    settings = {
      # uwsm widget removed — its uuctl action now lives on the Super+U keybind
      # (hyprland/lua/keybinds.lua). Only the on-screen-keyboard toggle remains.
      variants = [
        {
          icon = "⌨️";
          displayText = "";
          displayCommand = "";
          clickCommand = "sh ${config.home.homeDirectory}/killuanix/DotFiles/scripts/wvkbd-toggle.sh";
          middleClickCommand = "";
          rightClickCommand = "";
          updateInterval = 0;
          showIcon = true;
          showText = true;
          id = "variant_wvkbd";
          name = "On screen keyboard";
        }
      ];
    };
  };

  programs.dank-material-shell.plugins.dankHooks.enable = true;

  programs.dank-material-shell.plugins.dankPomodoroTimer.enable = true;

  # Remaining AvengeMedia/dms-plugins first-party plugins (all 12 enabled).
  programs.dank-material-shell.plugins.dankBatteryAlerts.enable = true;
  programs.dank-material-shell.plugins.dankClight.enable = true;
  programs.dank-material-shell.plugins.dankDesktopWeather.enable = true;
  programs.dank-material-shell.plugins.dankGifSearch.enable = true;
  programs.dank-material-shell.plugins.dankHyprlandWindows.enable = true;
  programs.dank-material-shell.plugins.dankKDEConnect.enable = true;
  programs.dank-material-shell.plugins.dankLauncherKeys.enable = true;
  programs.dank-material-shell.plugins.dankNotepadModule.enable = true;
  programs.dank-material-shell.plugins.dankStickerSearch.enable = true;

  # Both files are rewritten by DMS at runtime, so HM would otherwise refuse to
  # overwrite them on activation. plugin_settings.json is owned by the upstream
  # module (auto-active because dankActions ships `settings = { variants = … }`,
  # which flips `managePluginSettings` on); per-plugin `enabled` is derived from
  # each plugin's `enable` flag.
  xdg.configFile."DankMaterialShell/settings.json".force = lib.mkForce true;
  xdg.configFile."DankMaterialShell/plugin_settings.json".force = lib.mkForce true;

  # Qt caches compiled QML by source path. Plugin paths are stable across
  # store generations (~/.config/DankMaterialShell/plugins/<id>/Foo.qml),
  # so a content change can be masked by a stale .qmlc. Bust on every
  # activation — cheap, idempotent.
  home.activation.dmsQmlcacheBust = lib.hm.dag.entryAfter ["writeBoundary"] ''
    rm -rf "$HOME/.cache/quickshell/qmlcache"
  '';
}
