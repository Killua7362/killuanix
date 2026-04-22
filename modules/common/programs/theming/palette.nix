{
  config,
  lib,
  ...
}: {
  # Shared static palette — single source of truth for kitty, zellij,
  # qutebrowser. Starship inherits terminal colors, so it follows kitty.
  # Edit values here; rebuild to propagate.
  options.theme.palette = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    description = "Shared color palette for terminal/shell/browser theming.";
  };

  config.theme.palette = {
    # Base
    fg = "#e2e2e2";
    bg = "#131313";
    cursor = "#e2e2e2";
    cursor_text = "#c6c6c6";
    selection_fg = "#131313";
    selection_bg = "#89ceff";
    url = "#89ceff";

    # ANSI 16
    color0 = "#4c4c4c";
    color1 = "#ac8a8c";
    color2 = "#8aac8b";
    color3 = "#aca98a";
    color4 = "#89ceff";
    color5 = "#ac8aac";
    color6 = "#8aacab";
    color7 = "#f0f0f0";
    color8 = "#262626";
    color9 = "#c49ea0";
    color10 = "#9ec49f";
    color11 = "#c4c19e";
    color12 = "#a39ec4";
    color13 = "#c49ec4";
    color14 = "#9ec3c4";
    color15 = "#e7e7e7";

    # Zellij-specific (uses a slightly different bg than kitty)
    zellij_bg = "#1c1c1c";

    # Qutebrowser (Natsumi-derived surface family)
    surface = "#19191b";
    surface_alt = "#1e1f2b";
    surface_low = "#141416";
    surface_high = "#2a2a2e";
    outline = "#3a3a3e";
    selection = "#2f3456";
    selection_strong = "#ffffff";
    fg_bright = "#d4d4d4";
    fg_dim = "#9a9a9a";
    fg_dimmer = "#8a8a8e";
    fg_muted = "#4a4a4e";
    error = "#e2467a";
  };
}
