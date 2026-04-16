{
  pkgs,
  lib,
  ...
}: {
  config = lib.mkIf pkgs.stdenv.isLinux {
    xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        # Browser
        "text/html" = ["firefox-nightly.desktop"];
        "x-scheme-handler/http" = ["firefox-nightly.desktop"];
        "x-scheme-handler/https" = ["firefox-nightly.desktop"];
        "x-scheme-handler/about" = ["firefox-nightly.desktop"];
        "x-scheme-handler/unknown" = ["firefox-nightly.desktop"];
        "application/xhtml+xml" = ["firefox-nightly.desktop"];

        # File manager
        "inode/directory" = ["nemo.desktop"];

        # Images
        "image/png" = ["org.gnome.Loupe.desktop"];
        "image/jpeg" = ["org.gnome.Loupe.desktop"];
        "image/gif" = ["org.gnome.Loupe.desktop"];
        "image/webp" = ["org.gnome.Loupe.desktop"];
        "image/svg+xml" = ["org.gnome.Loupe.desktop"];
        "image/bmp" = ["org.gnome.Loupe.desktop"];
        "image/tiff" = ["org.gnome.Loupe.desktop"];

        # Video
        "video/mp4" = ["mpv.desktop"];
        "video/x-matroska" = ["mpv.desktop"];
        "video/webm" = ["mpv.desktop"];
        "video/x-msvideo" = ["mpv.desktop"];
        "video/quicktime" = ["mpv.desktop"];

        # Audio
        "audio/mpeg" = ["mpv.desktop"];
        "audio/flac" = ["mpv.desktop"];
        "audio/ogg" = ["mpv.desktop"];
        "audio/wav" = ["mpv.desktop"];

        # Text
        "text/plain" = ["nvim.desktop"];
        "text/x-shellscript" = ["nvim.desktop"];
        "application/json" = ["nvim.desktop"];
        "application/xml" = ["nvim.desktop"];
        "application/x-yaml" = ["nvim.desktop"];
        "text/markdown" = ["nvim.desktop"];
        "text/x-python" = ["nvim.desktop"];
        "text/x-csrc" = ["nvim.desktop"];
        "text/x-chdr" = ["nvim.desktop"];
        "text/x-c++src" = ["nvim.desktop"];
        "text/x-java" = ["nvim.desktop"];
        "text/css" = ["nvim.desktop"];
        "application/javascript" = ["nvim.desktop"];
        "application/x-shellscript" = ["nvim.desktop"];

        # Documents
        "application/pdf" = ["org.gnome.Papers.desktop"];

        # Archives
        "application/zip" = ["org.gnome.FileRoller.desktop"];
        "application/x-rar-compressed" = ["org.gnome.FileRoller.desktop"];
        "application/x-7z-compressed" = ["org.gnome.FileRoller.desktop"];
        "application/gzip" = ["org.gnome.FileRoller.desktop"];
        "application/x-tar" = ["org.gnome.FileRoller.desktop"];
        "application/x-bzip2" = ["org.gnome.FileRoller.desktop"];
        "application/x-xz" = ["org.gnome.FileRoller.desktop"];
        "application/x-compressed-tar" = ["org.gnome.FileRoller.desktop"];
      };
    };
  };
}
