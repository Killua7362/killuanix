-- Window rules + layer rules + workspace rules. Ported from windowrules.nix.
-- Workspaces.conf is empty so nothing extra is sourced here.

-- ============================================================================
-- Workspace rules
-- ============================================================================

hl.workspace_rule({ workspace = "special:special", gaps_out = 30 })

-- Per-host workspace → monitor pinning. Shared file, so gate by /etc/hostname.
local function read_hostname()
  local f = io.open("/etc/hostname", "r")
  if not f then return nil end
  local h = f:read("*l")
  f:close()
  return h
end

if read_hostname() == "chrollo" then
  hl.workspace_rule({ workspace = "1", monitor = "HDMI-A-1", default = true })
end

-- ============================================================================
-- Window rules
-- ============================================================================

-- Pinned-window border tint
hl.window_rule({ match = { pin = 1 }, border_color = "rgba(006591AA) rgba(00659177)" })

-- Blueman manager
hl.window_rule({ match = { class = "blueman-manager" }, float = 1 })
hl.window_rule({ match = { class = "blueman-manager" }, pin = 1 })
hl.window_rule({ match = { class = ".blueman-manager-wrapped" }, float = 1 })
hl.window_rule({ match = { class = ".blueman-manager-wrapped" }, pin = 1 })

-- Firefox PiP
hl.window_rule({ match = { class = "firefox-nightly", title = "Picture-in-Picture" }, float = 1 })
hl.window_rule({ match = { class = "firefox-nightly", title = "Picture-in-Picture" }, pin = 1 })
hl.window_rule({ match = { class = "firefox-nightly", title = "Picture-in-Picture" }, size = "525 300" })
hl.window_rule({ match = { class = "firefox-nightly", title = "Picture-in-Picture" }, move = "1380 80" })

-- Chrome PiP (Meet, YouTube, etc.) — PiP titles lack " - Google Chrome" suffix.
-- RE2 has no lookarounds; use Hyprland's `negative:` match prefix to scope.
hl.window_rule({ match = { class = "google-chrome", title = "negative:.*Google Chrome$" }, float = 1 })
hl.window_rule({ match = { class = "google-chrome", title = "negative:.*Google Chrome$" }, pin = 1 })
hl.window_rule({ match = { class = "google-chrome", title = "negative:.*Google Chrome$" }, size = "480 270" })
hl.window_rule({ match = { class = "google-chrome", title = "negative:.*Google Chrome$" }, move = "1420 790" })
hl.window_rule({ match = { class = "google-chrome", title = "negative:.*Google Chrome$" }, border_size = 0 })
hl.window_rule({ match = { class = "google-chrome", title = "negative:.*Google Chrome$" }, no_shadow = true })

-- Browser screen-share source picker (Firefox + Chrome/Chromium)
hl.window_rule({ match = { title = "^Select what to share.*$" }, float = 1 })
hl.window_rule({ match = { title = "^Select what to share.*$" }, center = 1 })
hl.window_rule({ match = { title = "^Select what to share.*$" }, size = "600 500" })

-- Satty (screenshot annotation)
hl.window_rule({ match = { title = "satty" }, float = 1 })
hl.window_rule({ match = { title = "satty" }, center = 1 })

-- Nautilus previewer
hl.window_rule({ match = { class = "^(org.gnome.NautilusPreviewer)$" }, float = 1 })

-- Empty class/title guard (carried from nix)
hl.window_rule({ match = { class = "^()$", title = " ^()$" }, no_blur = 1 })

-- File dialogs (centered + float)
local function file_dialog(pattern)
  hl.window_rule({ match = { title = pattern }, center = 1 })
  hl.window_rule({ match = { title = pattern }, float = 1 })
end
file_dialog(" ^(Open File)(.*)$")
file_dialog(" ^(Select a File)(.*)$")
file_dialog(" ^(Open Folder)(.*)$")
file_dialog(" ^(Save As)(.*)$")
file_dialog(" ^(Library)(.*)$")
file_dialog(" ^(File Upload)(.*)$")
file_dialog(" ^(.*)(wants to save)$")
file_dialog(" ^(.*)(wants to open)$")

-- Wallpaper chooser
hl.window_rule({ match = { title = " ^(Choose wallpaper)(.*)$" }, center = 1 })
hl.window_rule({ match = { title = " ^(Choose wallpaper)(.*)$" }, float = 1 })
hl.window_rule({ match = { title = " ^(Choose wallpaper)(.*)$" }, size = "60% 65%" })

-- Bluetooth + audio + JD + nm helpers
hl.window_rule({ match = { class = "^(blueberry\\.py)$" }, float = 1 })
hl.window_rule({ match = { class = "^(guifetch)$" }, float = 1 })

hl.window_rule({ match = { class = "^(org\\.pulseaudio\\.pavucontrol)$" }, float = 1 })
hl.window_rule({ match = { class = "^(org\\.pulseaudio\\.pavucontrol)$" }, size = "45% 45%" })
hl.window_rule({ match = { class = "^(org\\.pulseaudio\\.pavucontrol)$" }, center = 1 })

hl.window_rule({ match = { class = "^(com\\.saivert\\.pwvucontrol)$" }, float = 1 })
hl.window_rule({ match = { class = "^(com\\.saivert\\.pwvucontrol)$" }, size = "45% 45%" })
hl.window_rule({ match = { class = "^(com\\.saivert\\.pwvucontrol)$" }, center = 1 })

hl.window_rule({ match = { class = "org-jdownloader-update-launcher-JDLauncher" }, float = 1 })
hl.window_rule({ match = { class = "org-jdownloader-update-launcher-JDLauncher" }, size = "60% 60%" })
hl.window_rule({ match = { class = "org-jdownloader-update-launcher-JDLauncher" }, center = 1 })

hl.window_rule({ match = { class = "^(nm-connection-editor)$" }, float = 1 })
hl.window_rule({ match = { class = "^(nm-connection-editor)$" }, size = "45% 45%" })
hl.window_rule({ match = { class = "^(nm-connection-editor)$" }, center = 1 })

-- KDE / Plasma floats
hl.window_rule({ match = { class = ".*plasmawindowed.*" }, float = 1 })
hl.window_rule({ match = { class = "kcm_.*" }, float = 1 })
hl.window_rule({ match = { class = ".*bluedevilwizard" }, float = 1 })
hl.window_rule({ match = { title = " .*Welcome" }, float = 1 })
hl.window_rule({ match = { title = " ^(illogical-impulse Settings)$" }, float = 1 })
hl.window_rule({ match = { title = " .*Shell conflicts.*" }, float = 1 })
hl.window_rule({ match = { class = "org.freedesktop.impl.portal.desktop.kde" }, float = 1 })
hl.window_rule({ match = { class = "org.freedesktop.impl.portal.desktop.kde" }, size = "60% 65%" })

-- Zotero
hl.window_rule({ match = { class = "^(Zotero)$" }, float = 1 })
hl.window_rule({ match = { class = "^(Zotero)$" }, size = "45% 45%" })

-- Plasma changeicons (hide off-screen)
hl.window_rule({ match = { class = "^(plasma-changeicons)$" }, float = 1 })
hl.window_rule({ match = { class = "^(plasma-changeicons)$" }, no_initial_focus = 1 })
hl.window_rule({ match = { class = "^(plasma-changeicons)$" }, move = "999999 999999" })

-- Dolphin copy dialog
hl.window_rule({ match = { title = " ^(Copying — Dolphin)$" }, move = "40 80" })

-- Warp (force tile)
hl.window_rule({ match = { class = "^dev\\.warp\\.Warp$" }, tile = 1 })

-- Picture-in-Picture (generic title-based, not Firefox-specific)
local pip_match = " ^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$"
hl.window_rule({ match = { title = pip_match }, float = 1 })
hl.window_rule({ match = { title = pip_match }, keep_aspect_ratio = 1 })
hl.window_rule({ match = { title = pip_match }, move = "73% 72%" })
hl.window_rule({ match = { title = pip_match }, size = "25% 25%" })
hl.window_rule({ match = { title = pip_match }, pin = 1 })

-- Immediate (no animations) for fullscreen apps/games
hl.window_rule({ match = { title = " .*\\.exe" }, immediate = 1 })
hl.window_rule({ match = { title = " .*minecraft.*" }, immediate = 1 })
hl.window_rule({ match = { class = "^(steam_app).*" }, immediate = 1 })

-- Kodi: fullscreen, no blur/shadow, no xray
hl.window_rule({ match = { class = "^(kodi).*" }, immediate = 1 })
hl.window_rule({ match = { class = "^(kodi).*" }, no_blur = 1 })
hl.window_rule({ match = { class = "^(kodi).*" }, no_shadow = 1 })
hl.window_rule({ match = { class = "^(kodi).*" }, fullscreen = 1 })
hl.window_rule({ match = { class = "^(kodi).*" }, xray = 0 })

-- No shadow on tiled windows — `match.floating` not supported in 0.55 lua
-- window rules. Dropped; revisit with a different match (e.g. per-class)
-- if shadow on tiled windows becomes noticeable.

-- JetBrains (IntelliJ/WebStorm/etc) on Xwayland: win<N> popups misbehave.
hl.window_rule({ match = { class = "^(jetbrains-.*)$", title = "^(win.*)$" }, no_focus = 1 })
hl.window_rule({ match = { class = "^(.*jetbrains.*)$", title = "^(win.*)$" }, no_initial_focus = 1 })

-- Generic Xwayland win<N> tooltip catch-all
hl.window_rule({ match = { xwayland = 1, title = "^win[0-9]+$" }, float = 1 })
hl.window_rule({ match = { xwayland = 1, title = "^win[0-9]+$" }, no_focus = 1 })
hl.window_rule({ match = { xwayland = 1, title = "^win[0-9]+$" }, no_anim = 1 })

-- ============================================================================
-- Layer rules (quickshell + walker/anyrun/overview/etc.)
-- ============================================================================

-- no_anim namespaces
local no_anim_namespaces = {
  "walker", "selection", "overview", "anyrun", "indicator.*",
  "osk", "hyprpicker",
}
for _, ns in ipairs(no_anim_namespaces) do
  hl.layer_rule({ match = { namespace = ns }, no_anim = true })
end

-- gtk-layer-shell
hl.layer_rule({ match = { namespace = "gtk-layer-shell" }, blur = true })

-- launcher
hl.layer_rule({ match = { namespace = "launcher" }, blur = true })
hl.layer_rule({ match = { namespace = "launcher" }, ignore_alpha = 0.5 })

-- notifications
hl.layer_rule({ match = { namespace = "notifications" }, blur = true })
hl.layer_rule({ match = { namespace = "notifications" }, ignore_alpha = 0.69 })

-- wlogout
hl.layer_rule({ match = { namespace = "logout_dialog" }, blur = true })

-- side panels animation
hl.layer_rule({ match = { namespace = "sideleft.*" }, animation = "slide left" })
hl.layer_rule({ match = { namespace = "sideright.*" }, animation = "slide right" })

-- session bar
hl.layer_rule({ match = { namespace = "session[0-9]*" }, blur = true })

-- bar
hl.layer_rule({ match = { namespace = "bar[0-9]*" }, blur = true })
hl.layer_rule({ match = { namespace = "bar[0-9]*" }, ignore_alpha = 0.6 })
hl.layer_rule({ match = { namespace = "barcorner.*" }, blur = true })
hl.layer_rule({ match = { namespace = "barcorner.*" }, ignore_alpha = 0.6 })

-- dock
hl.layer_rule({ match = { namespace = "dock[0-9]*" }, blur = true })
hl.layer_rule({ match = { namespace = "dock[0-9]*" }, ignore_alpha = 0.6 })

-- indicator
hl.layer_rule({ match = { namespace = "indicator.*" }, blur = true })
hl.layer_rule({ match = { namespace = "indicator.*" }, ignore_alpha = 0.6 })

-- overview
hl.layer_rule({ match = { namespace = "overview[0-9]*" }, blur = true })
hl.layer_rule({ match = { namespace = "overview[0-9]*" }, ignore_alpha = 0.6 })

-- cheatsheet
hl.layer_rule({ match = { namespace = "cheatsheet[0-9]*" }, blur = true })
hl.layer_rule({ match = { namespace = "cheatsheet[0-9]*" }, ignore_alpha = 0.6 })

-- side panels numbered
hl.layer_rule({ match = { namespace = "sideright[0-9]*" }, blur = true })
hl.layer_rule({ match = { namespace = "sideright[0-9]*" }, ignore_alpha = 0.6 })
hl.layer_rule({ match = { namespace = "sideleft[0-9]*" }, blur = true })
hl.layer_rule({ match = { namespace = "sideleft[0-9]*" }, ignore_alpha = 0.6 })

-- osk
hl.layer_rule({ match = { namespace = "osk[0-9]*" }, blur = true })
hl.layer_rule({ match = { namespace = "osk[0-9]*" }, ignore_alpha = 0.6 })

-- quickshell global
hl.layer_rule({ match = { namespace = "quickshell:.*" }, blur_popups = true })
hl.layer_rule({ match = { namespace = "quickshell:.*" }, blur = true })
hl.layer_rule({ match = { namespace = "quickshell:.*" }, ignore_alpha = 0.79 })

-- quickshell per-widget animations
hl.layer_rule({ match = { namespace = "quickshell:bar" }, animation = "slide" })
hl.layer_rule({ match = { namespace = "quickshell:verticalBar" }, animation = "slide" })
hl.layer_rule({ match = { namespace = "quickshell:screenCorners" }, animation = "fade" })
hl.layer_rule({ match = { namespace = "quickshell:sidebarRight" }, animation = "slide right" })
hl.layer_rule({ match = { namespace = "quickshell:sidebarLeft" }, animation = "slide left" })
hl.layer_rule({ match = { namespace = "quickshell:wallpaperSelector" }, animation = "slide top" })
hl.layer_rule({ match = { namespace = "quickshell:osk" }, animation = "slide bottom" })
hl.layer_rule({ match = { namespace = "quickshell:dock" }, animation = "slide bottom" })
hl.layer_rule({ match = { namespace = "quickshell:cheatsheet" }, animation = "slide bottom" })

-- quickshell session (no anim)
hl.layer_rule({ match = { namespace = "quickshell:session" }, blur = true })
hl.layer_rule({ match = { namespace = "quickshell:session" }, no_anim = true })
hl.layer_rule({ match = { namespace = "quickshell:session" }, ignore_alpha = 0 })

-- quickshell notifications + bg widgets
hl.layer_rule({ match = { namespace = "quickshell:notificationPopup" }, animation = "fade" })
hl.layer_rule({ match = { namespace = "quickshell:backgroundWidgets" }, blur = true })
hl.layer_rule({ match = { namespace = "quickshell:backgroundWidgets" }, ignore_alpha = 0.05 })

-- quickshell misc
hl.layer_rule({ match = { namespace = "quickshell:screenshot" }, no_anim = true })
hl.layer_rule({ match = { namespace = "quickshell:screenCorners" }, animation = "popin 120%" })
hl.layer_rule({ match = { namespace = "quickshell:lockWindowPusher" }, no_anim = true })
hl.layer_rule({ match = { namespace = "quickshell:overview" }, no_anim = true })

-- gtk4-layer-shell
hl.layer_rule({ match = { namespace = "gtk4-layer-shell" }, no_anim = true })

-- shell:* (legacy ags-style)
hl.layer_rule({ match = { namespace = "shell:bar" }, blur = true })
hl.layer_rule({ match = { namespace = "shell:notifications" }, blur = true })
hl.layer_rule({ match = { namespace = "shell:notifications" }, ignore_alpha = 0.1 })

-- vicinae
hl.layer_rule({ match = { namespace = "vicinae" }, blur = true })
hl.layer_rule({ match = { namespace = "vicinae" }, ignore_alpha = 0 })
hl.layer_rule({ match = { namespace = "vicinae" }, no_anim = true })

-- wvkbd
hl.layer_rule({ match = { namespace = "wvkbd" }, ignore_alpha = 0 })
