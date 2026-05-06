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
    matugenTemplateGtk = true;
    matugenTemplateNiri = true;
    matugenTemplateHyprland = true;
    matugenTemplateMangowc = true;
    matugenTemplateQt5ct = true;
    matugenTemplateQt6ct = true;
    matugenTemplateFirefox = true;
    matugenTemplatePywalfox = true;
    matugenTemplateZenBrowser = true;
    matugenTemplateVesktop = true;
    matugenTemplateEquibop = true;
    matugenTemplateGhostty = true;
    matugenTemplateKitty = true;
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
