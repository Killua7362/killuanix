{
  programs.dank-material-shell.settings = {
    # ---- Fonts ----
    fontFamily = "Inter Variable";
    monoFontFamily = "Fira Code";
    fontWeight = 400;
    fontScale = 1;

    # ---- Notepad widget ----
    notepadUseMonospace = true;
    notepadFontFamily = "";
    notepadFontSize = 14;
    notepadShowLineNumbers = false;
    notepadTransparencyOverride = -1;
    notepadLastCustomTransparency = 0.7;

    # ---- Sounds ----
    soundsEnabled = true;
    useSystemSoundTheme = false;
    soundNewNotification = true;
    soundVolumeChanged = true;
    soundPluggedIn = true;

    # ---- Icon theme ----
    iconTheme = "System Default";

    # ---- Cursor (per-compositor inactivity-hide knobs) ----
    cursorSettings = {
      theme = "System Default";
      size = 24;
      niri = {
        hideWhenTyping = false;
        hideAfterInactiveMs = 0;
      };
      hyprland = {
        hideOnKeyPress = false;
        hideOnTouch = false;
        inactiveTimeout = 0;
      };
      dwl = {
        cursorHideTimeout = 0;
      };
    };
  };
}
