{
  config,
  pkgs,
  lib,
  ...
}: let
  p = config.theme.palette;

  # libadwaita / adw-gtk3 named-color overrides. Values propagate from
  # config.theme.palette (theming/palette.nix).
  gtkCss = ''
    @define-color accent_color ${p.color4};
    @define-color accent_bg_color ${p.color4};
    @define-color accent_fg_color ${p.bg};

    @define-color destructive_color ${p.error};
    @define-color destructive_bg_color ${p.error};
    @define-color destructive_fg_color ${p.selection_strong};

    @define-color success_color ${p.color2};
    @define-color success_bg_color ${p.color2};
    @define-color success_fg_color ${p.bg};

    @define-color warning_color ${p.color3};
    @define-color warning_bg_color ${p.color3};
    @define-color warning_fg_color ${p.bg};

    @define-color error_color ${p.error};
    @define-color error_bg_color ${p.error};
    @define-color error_fg_color ${p.selection_strong};

    @define-color window_bg_color ${p.bg};
    @define-color window_fg_color ${p.fg};

    @define-color view_bg_color ${p.bg};
    @define-color view_fg_color ${p.fg};

    @define-color headerbar_bg_color ${p.surface};
    @define-color headerbar_fg_color ${p.fg};
    @define-color headerbar_border_color ${p.outline};
    @define-color headerbar_backdrop_color ${p.surface_low};
    @define-color headerbar_shade_color ${p.surface_low};

    @define-color sidebar_bg_color ${p.surface};
    @define-color sidebar_fg_color ${p.fg};
    @define-color sidebar_backdrop_color ${p.surface_low};
    @define-color sidebar_shade_color ${p.surface_low};
    @define-color sidebar_border_color ${p.outline};

    @define-color secondary_sidebar_bg_color ${p.surface};
    @define-color secondary_sidebar_fg_color ${p.fg};
    @define-color secondary_sidebar_backdrop_color ${p.surface_low};
    @define-color secondary_sidebar_shade_color ${p.surface_low};
    @define-color secondary_sidebar_border_color ${p.outline};

    @define-color card_bg_color ${p.surface};
    @define-color card_fg_color ${p.fg};
    @define-color card_shade_color ${p.surface_low};

    @define-color dialog_bg_color ${p.surface_alt};
    @define-color dialog_fg_color ${p.fg};

    @define-color popover_bg_color ${p.surface_alt};
    @define-color popover_fg_color ${p.fg};
    @define-color popover_shade_color ${p.surface_low};

    @define-color thumbnail_bg_color ${p.surface};
    @define-color thumbnail_fg_color ${p.fg};

    @define-color shade_color ${p.surface_low};
    @define-color scrollbar_outline_color ${p.outline};
  '';
in {
  config = lib.mkIf pkgs.stdenv.isLinux {
    gtk = {
      gtk3.extraCss = gtkCss;
      gtk4.extraCss = gtkCss;
    };
  };
}
