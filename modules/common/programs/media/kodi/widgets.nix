# Declarative skinvariables node configs (home screen widgets, submenus, power menu, search)
{
  config,
  lib,
  pkgs,
  ...
}: {
  config = lib.mkIf pkgs.stdenv.isLinux {
    home.file.".kodi/userdata/addon_data/script.skinvariables/nodes/skin.arctic.fuse.3/skinvariables-shortcut-homewidgets.json".text = builtins.toJSON [
      {
        label = "Trending Movies";
        icon = "special://skin/extras/icons/film.png";
        path = "plugin://plugin.video.themoviedb.helper/?info=trending_day&tmdb_type=movie&widget=true";
        target = "videos";
        widget_style = "Landscape";
        guid = "guid-nix-home-01";
      }
      {
        label = "Popular TV Shows";
        icon = "special://skin/extras/icons/tv.png";
        path = "plugin://plugin.video.themoviedb.helper/?info=popular&tmdb_type=tv&widget=true";
        target = "videos";
        widget_style = "Landscape";
        guid = "guid-nix-home-02";
      }
      {
        label = "Top Rated Movies";
        icon = "special://skin/extras/icons/film.png";
        path = "plugin://plugin.video.themoviedb.helper/?info=top_rated&tmdb_type=movie&widget=true";
        target = "videos";
        widget_style = "Landscape";
        guid = "guid-nix-home-03";
      }
      {
        label = "Trending TV Shows";
        icon = "special://skin/extras/icons/tv.png";
        path = "plugin://plugin.video.themoviedb.helper/?info=trending_day&tmdb_type=tv&widget=true";
        target = "videos";
        widget_style = "Landscape";
        guid = "guid-nix-home-04";
      }
      {
        label = "Upcoming Movies";
        icon = "special://skin/extras/icons/film.png";
        path = "plugin://plugin.video.themoviedb.helper/?info=upcoming&tmdb_type=movie&widget=true";
        target = "videos";
        widget_style = "Landscape";
        guid = "guid-nix-home-05";
      }
    ];

    home.file.".kodi/userdata/addon_data/script.skinvariables/nodes/skin.arctic.fuse.3/skinvariables-shortcut-homesubmenu.json".text = builtins.toJSON [
      {
        label = "$LOCALIZE[3]";
        icon = "special://skin/extras/icons/video.png";
        path = "ActivateWindow(videos)";
        target = "";
        guid = "guid-nix-sub-01";
      }
      {
        label = "$LOCALIZE[249]";
        icon = "special://skin/extras/icons/songs.png";
        path = "ActivateWindow(music)";
        target = "";
        guid = "guid-nix-sub-02";
      }
      {
        label = "$LOCALIZE[1]";
        icon = "special://skin/extras/icons/image.png";
        path = "ActivateWindow(pictures)";
        target = "";
        guid = "guid-nix-sub-03";
      }
    ];

    home.file.".kodi/userdata/addon_data/script.skinvariables/nodes/skin.arctic.fuse.3/skinvariables-shortcut-powermenu.json".text = builtins.toJSON [
      {
        icon = "special://skin/extras/icons/favourites2.png";
        label = "$LOCALIZE[1036]";
        path = "ActivateWindow(1160)";
        target = "";
        guid = "guid-nix-pwr-01";
      }
      {
        icon = "special://skin/extras/icons/filebox.png";
        label = "$LOCALIZE[7]";
        path = "ActivateWindow(filemanager)";
        target = "";
        guid = "guid-nix-pwr-02";
      }
      {
        icon = "special://skin/extras/icons/address-card.png";
        label = "$LOCALIZE[31359]";
        path = "ActivateWindow(1195)";
        target = "";
        guid = "guid-nix-pwr-03";
      }
      {
        icon = "special://skin/extras/icons/power.png";
        label = "$LOCALIZE[13009]";
        path = "Quit()";
        target = "";
        guid = "guid-nix-pwr-04";
      }
    ];

    home.file.".kodi/userdata/addon_data/script.skinvariables/nodes/skin.arctic.fuse.3/skinvariables-shortcut-searchwidgets.json".text = builtins.toJSON [
      {
        label = "Movies";
        icon = "special://skin/extras/icons/film.png";
        path = "DefaultSearch-Movies";
        target = "videos";
        widget_style = "Poster";
        guid = "guid-nix-srch-01";
      }
      {
        label = "TV Shows";
        icon = "special://skin/extras/icons/tv.png";
        path = "DefaultSearch-TvShows";
        target = "videos";
        widget_style = "Poster";
        guid = "guid-nix-srch-02";
      }
      {
        label = "Movies (TMDb)";
        icon = "special://skin/extras/icons/film.png";
        path = "DefaultSearch-TMDBMovies";
        target = "videos";
        widget_style = "Poster";
        guid = "guid-nix-srch-03";
      }
      {
        label = "TV Shows (TMDb)";
        icon = "special://skin/extras/icons/tv.png";
        path = "DefaultSearch-TMDBShows";
        target = "videos";
        widget_style = "Poster";
        guid = "guid-nix-srch-04";
      }
    ];
  };
}
