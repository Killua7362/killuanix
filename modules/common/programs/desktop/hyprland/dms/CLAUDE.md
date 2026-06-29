# DankMaterialShell (`dms/`) — modular config

This folder configures `programs.dank-material-shell` (HM module from flake input
`dms = github:AvengeMedia/DankMaterialShell/stable`). It replaces the old single
`hyprland/dms.nix` file. Each topic file contributes a slice of
`programs.dank-material-shell.settings` (the JSON written to
`~/.config/DankMaterialShell/settings.json`); the Nix module system merges them
attribute-wise.

`default.nix` owns everything outside the settings attrset: `enable`, the
commented module-level option reference (`systemd`, `enable*`, `quickshell.package`,
`dgop.package`, `clipboardSettings`, `session`), the plugin schema example, the
`leaderHud` plugin wiring, and the `xdg.configFile.…force = lib.mkForce true`
escape hatch.

## Plugins

Two sources:

- **`dms-plugin-registry`** (flake input `dms-plugin-registry =
  github:AvengeMedia/dms-plugin-registry`) — its homeModule
  (`inputs.dms-plugin-registry.homeModules.default`, imported alongside the dms
  module in `flake.nix` archnix + `chrollo/home-manager/home.nix` +
  `killua/home.nix`) registers **all 238 registry plugins** with
  `enable = mkDefault false` and a prefetched `src`. To use one, just set
  `programs.dank-material-shell.plugins.<id>.enable = true;` (+ optional
  `settings`); do **not** set `src` (that conflicts with the registry's own
  `src` def). The `<id>` is the registry id (e.g. `dankActions`,
  `dankBatteryAlerts`) — last path segment of the install URL on
  https://danklinux.com/plugins. Currently enabled: all 12 first-party
  `AvengeMedia/dms-plugins` (`dankActions` — with `settings.variants` —
  `dankBatteryAlerts`, `dankClight`, `dankDesktopWeather`, `dankGifSearch`,
  `dankHooks`, `dankHyprlandWindows`, `dankKDEConnect`, `dankLauncherKeys`,
  `dankNotepadModule`, `dankPomodoroTimer`, `dankStickerSearch`). **Bumping** all
  registry plugins = `nix flake update dms-plugin-registry` (daily-updated
  upstream pin in `flake.lock`); no per-plugin rev/sha to maintain.
- **Local / out-of-registry** — set `src` manually (package or path). Only
  `leaderHud` (`src = ../../qml/leader-hud`) uses this; it's an in-repo QML
  plugin not in the registry.

## When you want to change X, open Y

| Topic | File | Owns |
|---|---|---|
| Module-level toggles, plugins, `clipboardSettings`, `session`, mkForce | `default.nix` | `enable`, `systemd.*`, `dgop.package`, `quickshell.package`, `enableSystemMonitoring`, `enableVPN`, `enableDynamicTheming`, `enableAudioWavelength`, `enableCalendarEvents`, `enableClipboardPaste`, `managePluginSettings`, `clipboardSettings`, `session`, `plugins.<name>` |
| Theme / matugen / animations / wallpaper visuals | `theme.nix` | `currentTheme*`, `matugen*` (scheme/runUser/targetMonitor only — templates live in `theming-templates.nix`), `popupTransparency`, `dockTransparency`, `widgetBackgroundColor`, `widgetColorMode`, `controlCenterTileColorMode`, `buttonColorMode`, `cornerRadius`, `*LayoutGapsOverride` / `*LayoutRadiusOverride` / `*LayoutBorderSize` (niri/hyprland/mango), `animationSpeed`, `customAnimationDuration`, `syncComponentAnimationSpeeds`, `popoutAnimationSpeed`, `popoutCustomAnimationDuration`, `modalAnimationSpeed`, `modalCustomAnimationDuration`, `enableRippleEffects`, `modalDarkenBackground`, `wallpaperFillMode`, `blurredWallpaperLayer`, `blurWallpaperOnOverview`, `nightModeEnabled` |
| Top bar (widgets, layout, music visualizer, workspaces, `barConfigs`) | `bar.nix` | `show{LauncherButton,WorkspaceSwitcher,FocusedWindow,Weather,Music,Clipboard,CpuUsage,MemUsage,CpuTemp,GpuTemp,SystemTray,Clock,NotificationButton,Battery,ControlCenterButton,CapsLockIndicator}`, `clockCompactMode`, `focusedWindowCompactMode`, `runningApps*`, `keyboardLayoutNameCompactMode`, `appIdSubstitutions`, `centeringMode`, `barMaxVisible*`, `barShowOverflowBadge`, `appsDock*` (bar-side dock indicators), `waveProgressEnabled`, `scrollTitleEnabled`, `audioVisualizerEnabled`, `audioScrollMode`, `audioWheelScrollAmount`, `mediaSize`, `showWorkspace*`, `workspaceScrolling`, `workspaceDragReorder`, `maxWorkspaceIcons`, `workspaceAppIconSizeOffset`, `groupWorkspaceApps`, `workspaceFollowFocus`, `showOccupiedWorkspacesOnly`, `reverseScrolling`, `dwlShowAllTags`, `workspace*ColorMode`, `workspaceFocusedBorder*`, `workspaceNameIcons`, `barConfigs` (full per-bar object) |
| Control-center popup (button icons, privacy chip, tile widgets) | `control-center.nix` | `controlCenterShow*`, `showPrivacyButton`, `privacyShow*`, `controlCenterWidgets` |
| Bottom dock (visibility, indicators, dock-launcher) | `dock.nix` | `showDock`, `dockAutoHide`, `dockSmartAutoHide`, `dockGroupByApp`, `dockOpenOnOverview`, `dockPosition`, `dockSpacing`, `dockBottomGap`, `dockMargin`, `dockIconSize`, `dockIndicatorStyle`, `dockBorder*`, `dockIsolateDisplays`, `dockMaxVisible*`, `dockShowOverflowBadge`, `dockLauncher*` |
| Spotlight / app launcher / niri overview | `launcher.nix` | `launcherLogo*`, `dankLauncherV2*`, `appLauncherViewMode`, `spotlightModalViewMode`, `browserPickerViewMode`, `appPickerViewMode`, `sortAppsAlphabetically`, `appLauncherGridColumns`, `spotlightCloseNiriOverview`, `spotlightSectionViewModes`, `appDrawerSectionViewModes`, `browserUsageHistory`, `filePickerUsageHistory`, `niriOverviewOverlayEnabled`, commented `overviewRows`/`Columns`/`Scale` |
| Greeter (login screen) | `greeter.nix` | `greeter*` (RememberLast*, EnableFprint/U2f, Wallpaper*, Use24Hour, Show*, PadHours12Hour, LockDateFormat, FontFamily) |
| Notifications & OSD overlay | `notifications.nix` | `notification*` (popup, history, rules, timeouts, animation), `osd*` |
| Lock screen + idle + power profile + power menu + updater | `lock-power.nix` | `lockScreen*`, `enableFprint`, `maxFprintTries`, `enableU2f`, `u2fMode`, `lockBeforeSuspend`, `loginctlLockIntegration`, `fadeToLock*`, `fadeToDpms*`, `lockAtStartup`, `hideBrightnessSlider`, `ac*`/`battery*` profile timeouts + `batteryChargeLimit`, `powerActionConfirm`, `powerActionHoldDuration`, `powerMenuActions`/`DefaultAction`/`GridLayout`, `customPowerAction*`, `updater*` |
| GTK/Qt theming + per-app matugen template toggles | `theming-templates.nix` | `gtkThemingEnabled`, `qtThemingEnabled`, `syncModeWithPortal`, `terminalsAlwaysDark`, `runDmsMatugenTemplates`, `matugenTemplate*` (Gtk, Niri, Hyprland, Mangowc, Qt5ct, Qt6ct, Firefox, Pywalfox, ZenBrowser, Vesktop, Equibop, Ghostty, Kitty, Foot, Alacritty, Neovim, Wezterm, Dgop, Kcolorscheme, Vscode, Emacs, Zed) |
| Fonts, notepad, sounds, icons, cursor | `fonts-sounds.nix` | `fontFamily`, `monoFontFamily`, `fontWeight`, `fontScale`, `notepad*`, `soundsEnabled`, `useSystemSoundTheme`, `sound{NewNotification,VolumeChanged,PluggedIn}`, `iconTheme`, `cursorSettings` (theme + size + per-compositor hide knobs) |
| Multi-monitor profiles, desktop-clock widget, system-monitor widget | `display.nix` | `displayNameMode`, `screenPreferences`, `showOnLastDisplay`, `niriOutputSettings`, `hyprlandOutputSettings`, `displayProfiles`, `activeDisplayProfile`, `displayProfileAutoSelect`, `displayShowDisconnected`, `displaySnapToEdge`, `desktopClock*`, `systemMonitor*`, `desktopWidgetPositions`/`GridSettings`/`Instances`/`Groups` |
| Time / weather units, network, GPU pick, device pins, plugin settings, `configVersion` | `misc.nix` | `use24HourClock`, `showSeconds`, `padHours12Hour`, `useFahrenheit`, `windSpeedUnit`, `weatherEnabled`, `useAutoLocation`, `clockDateFormat`, `lockDateFormat`, `networkPreference`, `launchPrefix`, `clipboardEnterToPaste`, `selectedGpuIndex`, `enabledGpuPciIds`, `*DevicePins` (brightness/wifi/bluetooth/audioInput/audioOutput), `builtInPluginSettings`, `launcherPluginVisibility`, `launcherPluginOrder`, `configVersion` |

## How merging works

Each file does:

```nix
{
  programs.dank-material-shell.settings = {
    fontFamily = "Inter Variable";
    # ...
  };
}
```

The HM option `settings` is `pkgs.formats.json {}` typed — recursive `attrsOf`,
which the module system merges attribute-wise across files. This is why a key
must live in **exactly one** file (Nix raises a duplicate-definition error
otherwise) and why list values like `barConfigs` and `controlCenterWidgets` are
each in a single file (lists concatenate, which would produce nonsense).

## Adding a new key

1. Find the topic file from the table above. If you're not sure, `grep -rn
   <prefix>` inside this folder — every key currently in `settings.json` lives
   somewhere here.
2. Add the line. If the upstream default already matches the desired value,
   leave it as a comment so a future reader knows it exists.
3. After editing, run the verification block from the parent
   `hyprland/CLAUDE.md` ("DMS settings drift check") to confirm the built
   `settings.json` still matches your live one.

## Where the upstream truth lives

When you need to verify a key name, type, or default, browse the DMS source via
the flake input's store path. Resolve once per session with:

```bash
nix flake archive --json | python3 -c \
  "import json,sys; print(json.load(sys.stdin)['inputs']['dms']['path'])"
```

Then read:

- `quickshell/Common/SettingsData.qml` — every `settings.json` key (look for
  `property <type> <name>: <default>`).
- `quickshell/Common/SessionData.qml` — every `session.json` key.
- `core/internal/server/clipboard/types.go` — `clipboardSettings` (clsettings.json)
  schema.
- `distro/nix/options.nix` and `distro/nix/home.nix` — module-level options
  exposed to Nix.

## Things intentionally not configured here

- Readonly / probe-only QML state (`fprintdAvailable`, `gtkAvailable`,
  `qt5ctAvailable`, `available{Icon,Cursor}Themes`, `lock{Fingerprint,U2f}*`,
  …) — DMS sets these at runtime; writing them into `settings.json` does
  nothing.
- Bar widget list-model aliases (`dankBarLeftWidgetsModel` and friends) — those
  are populated from `barConfigs[*].leftWidgets`/`centerWidgets`/`rightWidgets`,
  which we already configure in `bar.nix`.
- Removed/renamed options that the HM module rejects via
  `mkRemovedOptionModule` / `mkRenamedOptionModule`:
  `enableBrightnessControl`, `enableColorPicker`, `enableClipboard`,
  `enableSystemSound`, `enableNightMode`, `default.settings`, `default.session`;
  and the rename `enableSystemd` → `systemd.enable`. Setting any of these
  raises an eval error.

## Verification (drift check)

The merged settings can be diffed against the live activated `settings.json`:

```bash
RES=$(nix build --no-link --print-out-paths --impure --expr \
  '(builtins.getFlake (toString ./.)).homeManagerConfigurations.killua.activationPackage')
python3 -c "
import json
a = json.load(open('$HOME/.config/DankMaterialShell/settings.json'))
b = json.load(open('$RES/home-files/.config/DankMaterialShell/settings.json'))
diff = {k: (a.get(k), b.get(k)) for k in set(a) | set(b) if a.get(k) != b.get(k)}
print('IDENTICAL' if not diff else f'DIFFERS: {diff}')
"
```

If this prints anything other than `IDENTICAL`, the merge introduced a drift —
the diff names exactly which keys disagree.
