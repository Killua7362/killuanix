{
  config,
  pkgs,
  lib,
  ...
}: {
  config = lib.mkIf pkgs.stdenv.isLinux {
    # Nemo file manager with extensions
    home.packages = with pkgs; [
      (nemo-with-extensions.override {
        extensions = [
          nemo-fileroller # Archive management (compress/extract from context menu)
          nemo-emblems # Custom folder/file emblems
          nemo-python # Python plugin support
        ];
      })
      # Supporting packages
      file-roller # Archive manager backend
      webp-pixbuf-loader # WebP thumbnail support
      ffmpegthumbnailer # Video thumbnail support
    ];

    # Nemo dconf settings — dark theme, sensible defaults
    dconf.settings = {
      "org/nemo/preferences" = {
        show-hidden-files = false;
        default-folder-viewer = "list-view";
        show-location-entry = true; # Editable path bar by default
        date-format = "iso";
        thumbnail-limit = lib.hm.gvariant.mkUint64 4294967295; # ~4GB thumbnail limit
        show-image-thumbnails = "always";
        ignore-view-metadata = false;
        close-device-view-on-device-eject = true;
      };

      "org/nemo/list-view" = {
        default-visible-columns = ["name" "size" "type" "date_modified" "permissions"];
        default-zoom-level = "small";
      };

      "org/nemo/icon-view" = {
        default-zoom-level = "standard";
      };

      "org/nemo/preferences/menu-config" = {
        selection-menu-make-link = true;
        selection-menu-copy-to = true;
        selection-menu-move-to = true;
      };

      "org/nemo/window-state" = {
        sidebar-bookmark-breakpoint = 0;
        start-with-sidebar = true;
      };

      # File previewer plugin
      "org/nemo/extensions/nemo-preview" = {
        active = true;
      };

      # Terminal integration — open terminal here uses kitty
      "org/cinnamon/desktop/applications/terminal" = {
        exec = "kitty";
        exec-arg = "";
      };

      # Dark theme preference for Nemo (inherits GTK theme via org/gnome/desktop/interface)
      "org/nemo/desktop" = {
        font = "JetBrainsMono Nerd Font 11";
      };
    };

    # Nemo as default for saved searches (directory default is in mimeapps.nix)
    xdg.mimeApps.defaultApplications = {
      "application/x-gnome-saved-search" = ["nemo.desktop"];
    };
  };
}
