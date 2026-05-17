# RSSGuard — Qt-based desktop RSS reader, paired with the local FreshRSS
# container (see modules/containers/freshrss/).
#
# `~/.config/RSS Guard 4/config/config.ini` is rendered from this attrset via
# `lib.generators.toINI`. Once switched, the file becomes a read-only symlink
# into the nix store — RSSGuard's "Save settings" silently no-ops for any key
# we manage here. Anything we deliberately don't set (window geometry,
# splitter sizes, expand-states, feed/msg view blobs) is volatile and stays
# writable inside RSSGuard's SQLite database instead.
#
# Section names MUST be lowercase — Qt's QSettings INI backend writes them
# that way (confirmed against upstream src/librssguard/miscellaneous/settings.cpp).
#
# Defaults below mirror the source-of-truth defaults from settings.cpp, with
# personal preferences overlaid. Each commented entry is a known-good knob
# you can flip without further research.
{
  pkgs,
  lib,
  config,
  ...
}:
lib.mkIf pkgs.stdenv.isLinux {
  home.packages = [pkgs.rssguard];

  # Path uses RSSGuard's actual AppName ("RSS Guard 4" with spaces) — that's
  # what QStandardPaths resolves to. The legacy "rssguard4" dir is a no-op.
  xdg.configFile."RSS Guard 4/config/config.ini".text = lib.generators.toINI {} {
    main = {
      disable_debug_output = true;
      update_on_start = false;
      first_run = false; # skip welcome wizard
      language = "en_US";
    };

    gui = {
      # Built-in skins: minimal-light, minimal-dark, minimal-base. Drop a
      # custom skin into ~/.config/RSS Guard 4/skins/<name>/ to use another.
      skin = "minimal-dark";
      style = "Fusion";
      forced_skin_colors = true;
      use_tray_icon = true;
      monochrome_tray_icon = false;
      colored_busy_tray_icon = true;
      show_unread_numbers_in_tray_icon = true;
      show_unread_numbers_on_task_bar = true;
      show_unread_numbers_on_window = true;
      hide_when_minimized = true;
      start_hidden = false;
      start_in_fullscreen = false;
      main_menu_visible = true;
      enable_toolbars = true;
      enable_list_headers = true;
      message_viewer_toolbars = true;
      enable_status_bar = true;
      hide_tabbar_one_tab = true;
      tab_close_mid_button = true;
      tab_close_double_button = true;
      tab_new_double_button = true;
      alternate_colors_in_lists = true;
      toolbar_icon_size = 20;
      toolbar_style = 0; # Qt::ToolButtonIconOnly (1=text, 2=text-beside, 3=text-under)
      font_antialiasing = true;
      enable_notifications = true;
      use_toast_notifications = true;
      toast_notifications_position = 2; # BottomRight
      toast_notifications_duration = 5000;
      toast_notifications_opacity = "0.9";
    };

    feeds = {
      feed_update_timeout = 15000; # ms per-feed fetch timeout
      count_format = "%unread-%all";
      count_alignment = 132; # Qt::AlignCenter
      keep_cursor_center = true;
      show_tooltips = true;
      strikethrough_disabled_feeds = true;
      dont_ask_when_marking_all_read = false;
      auto_update_enabled = true;
      auto_update_interval = 15; # minutes
      auto_update_fast = false;
      auto_update_only_unfocused = false;
      feeds_update_on_startup = true;
      feeds_update_on_startup_delay = 30;
      sort_alphabetically = false;
      show_tree_branches = true;
      hide_counts_if_no_unread = false;
      update_feed_list_during_fetching = true;
      auto_expand_on_selection = false;
      only_basic_shortcuts_in_lists = false;
      propagate_feed_list_states = true;
      # fetch_only_when_network = true;     # skip refresh when offline
      # fetch_only_when_not_gamemode = true; # honor GameMode inhibitor
    };

    messages = {
      message_head_image_height = 72;
      show_enclosures_in_message = true;
      avoid_old_articles = false;
      copy_article_pattern = "%6% - %8%"; # title - url
      copy_article_escape_csv = false;
      font_aa = true;
      shape_aa = true;
      article_list_lazy_loading = false;
      mark_message_on_selected = 1; # 0=immediately, 1=after delay, 2=never
      mark_message_on_selected_delay = 3000;
      limit_dont_remove_unread = true;
      limit_dont_remove_starred = true;
      limit_recycle_dont_purge = false;
      limit_count_of_articles = 0; # 0 = unlimited
      always_display_preview = true;
      enable_message_preview = true;
      enable_message_resources = true;
      zoom = "1.0";
      fixup_future_datetimes = true;
      ignore_contents_changes = true;
      mark_unread_on_update = false;
      bring_app_to_front_after_msg_opened = false;
      keep_cursor_center = true;
      show_only_unread_messages = false;
      show_feed_icon_in_feed_column = true;
      multiline_article_list = false;
      switch_article_list_rtl = false;
      unread_icons_in_message_list = 1;
      # clear_read_on_exit = true;            # purge read articles on quit
      # use_custom_date = true;
      # custom_date_format = "yyyy-MM-dd hh:mm";
    };

    browser = {
      load_external_resources = true;
      custom_external_browser = true;
      external_browser_executable = "firefox";
      external_browser_arguments = "%1";
      # custom_external_email = true;
      # external_email_executable = "thunderbird";
      # external_email_arguments = "-compose to=%1,subject=%2,body=%3";
    };

    network = {
      send_dnt = true;
      http2_enabled = true;
      # user_agent = "Mozilla/5.0 (X11; Linux x86_64) RSSGuard/4";
    };

    # proxy = {
    #   proxy_type = 0;           # 0=Default, 1=Socks5, 2=Http, 3=No
    #   host = "";
    #   port = 80;
    #   username = "";
    # };

    database = {
      database_driver = "QSQLITE";
      # Switch to mysql by setting these + database_driver = "QMYSQL".
      # mysql_hostname = "127.0.0.1";
      # mysql_username = "rssguard";
      # mysql_database = "rssguard";
      # mysql_port = 3306;
    };

    web = {
      follow_links = true;
      # Only honored when RSSGuard is built with QtWebEngine (the nixpkgs
      # rssguard package is — keep the flag here for clarity).
      webengine_flags = "--enable-smooth-scrolling";
    };
  };
}
