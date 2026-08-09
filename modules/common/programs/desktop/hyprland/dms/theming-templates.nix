{
  programs.dank-material-shell.settings = {
    # ---- App theming integration ----
    gtkThemingEnabled = false;
    qtThemingEnabled = false;
    syncModeWithPortal = true;
    terminalsAlwaysDark = false;

    # ---- Matugen template runner ----
    # When enabled, DMS regenerates per-app theme files whenever the wallpaper /
    # palette changes. Each `matugenTemplate*` toggle controls one target.
    runDmsMatugenTemplates = true;
    # kitty/GTK/Qt5ct/Qt6ct configs are owned by nix as read-only symlinks
    # (static theme/palette modules), so DMS's matugen output for them lands in
    # orphaned sidecar files nothing reads. Disabled to stop generating dead files.
    matugenTemplateGtk = false;
    matugenTemplateNiri = true;
    matugenTemplateHyprland = true;
    matugenTemplateMangowc = true;
    matugenTemplateQt5ct = false;
    matugenTemplateQt6ct = false;
    matugenTemplateFirefox = true;
    matugenTemplatePywalfox = true;
    matugenTemplateZenBrowser = true;
    matugenTemplateVesktop = true;
    matugenTemplateEquibop = true;
    matugenTemplateGhostty = true;
    matugenTemplateKitty = false;
    matugenTemplateFoot = true;
    matugenTemplateAlacritty = true;
    matugenTemplateNeovim = false;
    matugenTemplateWezterm = true;
    matugenTemplateDgop = true;
    matugenTemplateKcolorscheme = true;
    matugenTemplateVscode = true;
    matugenTemplateEmacs = true;
    matugenTemplateZed = true;
  };
}
