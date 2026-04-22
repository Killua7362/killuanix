{
  config,
  pkgs,
  lib,
  ...
}: let
  p = config.theme.palette;

  # Reuse KvFlat's widget SVG (shapes/gradients). We override every color
  # through the Kvantum .kvconfig so only visuals come from KvFlat; all
  # palette entries come from config.theme.palette.
  kvantumPkg = pkgs.qt6Packages.qtstyleplugin-kvantum;
  baseSvg = "${kvantumPkg}/share/Kvantum/KvFlat/KvFlat.svg";

  kvantumThemeName = "KilluaPalette";

  kvantumConfig = ''
    [%General]
    author=killua
    comment=Static palette from config.theme.palette
    x11drag=all
    alt_mnemonic=true
    left_tabs=false
    attach_active_tab=true
    group_toolbar_buttons=false
    spread_progressbar=true
    progressbar_thickness=3font
    composite=true
    menu_shadow_depth=6
    spread_menuitems=true
    tooltip_shadow_depth=6
    splitter_width=7
    scroll_width=12
    scroll_min_extent=50
    scroll_arrows=false
    combo_as_lineedit=true
    inline_spin_indicators=true
    slider_width=6
    slider_handle_width=16
    slider_handle_length=16
    check_size=16
    toolbar_icon_size=16
    animate_states=true
    transient_groove=false
    transient_scrollbar=true

    [GeneralColors]
    window.color=${p.bg}
    base.color=${p.bg}
    alt.base.color=${p.surface}
    button.color=${p.surface_alt}
    light.color=${p.surface_high}
    mid.light.color=${p.surface_alt}
    dark.color=${p.color8}
    mid.color=${p.surface}
    highlight.color=${p.color4}
    inactive.highlight.color=${p.selection}
    text.color=${p.fg}
    window.text.color=${p.fg}
    button.text.color=${p.fg}
    disabled.text.color=${p.fg_dim}
    tooltip.text.color=${p.fg}
    highlight.text.color=${p.bg}
    link.color=${p.color4}
    link.visited.color=${p.color5}

    [Hacks]
    respect_darkness=true
    transparent_ktitle_label=true
  '';

  # qt5ct/qt6ct still own the Qt palette as a safety net for apps that
  # bypass Kvantum (or render widgets not styled by Kvantum). Keeps
  # tooltips / dialogs aligned with the palette.
  join = lib.concatStringsSep ", ";
  activeColors = join [
    p.fg p.surface p.surface_high p.surface_high p.surface_low p.surface
    p.fg p.selection_strong p.fg p.bg p.bg p.color8
    p.color4 p.bg p.color4 p.color5
    p.surface p.bg p.surface_alt p.fg p.fg_dim
  ];
  disabledColors = join [
    p.fg_dim p.surface p.surface_high p.surface_high p.surface_low p.surface
    p.fg_dim p.fg p.fg_dim p.bg p.bg p.color8
    p.surface_high p.fg_dim p.color4 p.color5
    p.surface p.bg p.surface_alt p.fg_dim p.fg_dimmer
  ];
  inactiveColors = activeColors;

  colorScheme = ''
    [ColorScheme]
    active_colors=${activeColors}
    disabled_colors=${disabledColors}
    inactive_colors=${inactiveColors}
  '';

  mkQtctConf = name: ''
    [Appearance]
    style=kvantum
    custom_palette=true
    color_scheme_path=${config.home.homeDirectory}/.config/${name}/colors/static.conf
    standard_dialogs=default
    icon_theme=Adwaita
  '';
in {
  config = lib.mkIf pkgs.stdenv.isLinux {
    home.packages = with pkgs; [
      libsForQt5.qtstyleplugin-kvantum
      qt6Packages.qtstyleplugin-kvantum
    ];

    # qtct handles palette, kvantum handles widget styling.
    qt.platformTheme.name = lib.mkForce "qtct";
    qt.style = lib.mkForce {
      name = "kvantum";
      package = null;
    };

    home.sessionVariables = {
      QT_QPA_PLATFORMTHEME = lib.mkForce "qt5ct";
      QT_QPA_PLATFORMTHEME_QT6 = lib.mkForce "qt6ct";
      QT_STYLE_OVERRIDE = lib.mkForce "kvantum-dark";
    };

    xdg.configFile = {
      # Qt palette (fallback + source of truth for non-Kvantum rendering)
      "qt5ct/colors/static.conf".text = colorScheme;
      "qt6ct/colors/static.conf".text = colorScheme;
      "qt5ct/qt5ct.conf".text = mkQtctConf "qt5ct";
      "qt6ct/qt6ct.conf".text = mkQtctConf "qt6ct";

      # Kvantum: select our custom theme
      "Kvantum/kvantum.kvconfig".text = ''
        [General]
        theme=${kvantumThemeName}
      '';

      # Custom Kvantum theme: KvFlat widget SVG + palette-driven .kvconfig
      "Kvantum/${kvantumThemeName}/${kvantumThemeName}.svg".source = baseSvg;
      "Kvantum/${kvantumThemeName}/${kvantumThemeName}.kvconfig".text = kvantumConfig;
    };
  };
}
