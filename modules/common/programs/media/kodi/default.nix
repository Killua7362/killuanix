# Kodi media center — main entry point
# Assembles custom addons, wraps the launcher with pre-launch DB bootstrapping,
# deploys the Arctic Fuse skin, widgets, and injects secrets via activation scripts.
{
  config,
  pkgs,
  lib,
  ...
}: let
  kodiPlatform =
    if pkgs.stdenv.isLinux
    then pkgs.kodi-wayland
    else pkgs.kodi;

  # Custom addon derivations
  customAddons = import ./addons.nix {inherit pkgs lib kodiPlatform;};

  # Resolve inter-addon dependencies
  soupsieve = customAddons.soupsieve;
  beautifulsoup4 = customAddons.beautifulsoup4 {inherit soupsieve;};
  context-seren = customAddons.context-seren;
  unidecode = customAddons.unidecode;
  myconnpy = customAddons.myconnpy;
  seren = customAddons.seren {inherit context-seren unidecode beautifulsoup4 myconnpy;};

  kodiWithAddons = kodiPlatform.withPackages (kodiPkgs:
    with kodiPkgs; [
      # Skin (installed via activation to ~/.kodi/addons/ for skinvariables writes)
      customAddons.skinvariables

      # Repositories
      customAddons.repo-umbrella
      customAddons.repo-jurialmunkey
      customAddons.repo-cocoscrapers
      customAddons.repo-nixgates

      # Tracking
      trakt
      trakt-module
      customAddons.simkl

      # Video addons
      customAddons.umbrella
      customAddons.fenlight
      seren
      customAddons.tmdb-helper

      # Seren dependencies
      unidecode
      beautifulsoup4
      soupsieve
      context-seren
      myconnpy

      # Scrapers
      customAddons.cocoscrapers

      # Subtitles
      a4ksubtitles

      # Utilities
      customAddons.openwizard
      inputstream-adaptive
      inputstreamhelper
      youtube
    ]);

  kodiAddonData = "${config.home.homeDirectory}/.kodi/userdata/addon_data";

  # Kodi's internal UUID for system-origin addons (from xbmc/addons/AddonRepos.h)
  originSystem = "b6a50484-93a0-4afb-a01c-8d17e059feda";

  # Addon IDs that should be enabled on fresh install (must match namespaces above)
  managedAddonIds = [
    # Skin
    "skin.arctic.fuse.3"
    "script.skinvariables"
    # Repositories
    "repository.umbrella"
    "repository.jurialmunkey"
    "repository.cocoscrapers"
    "repository.nixgates"
    # Tracking
    "script.trakt"
    "script.module.trakt"
    "script.simkl"
    # Video addons
    "plugin.video.umbrella"
    "plugin.video.fenlight"
    "plugin.video.seren"
    "plugin.video.themoviedb.helper"
    # Seren dependencies
    "script.module.unidecode"
    "script.module.beautifulsoup4"
    "script.module.soupsieve"
    "context.seren"
    "script.module.myconnpy"
    # Scrapers
    "script.module.cocoscrapers"
    # Subtitles
    "service.subtitles.a4ksubtitles"
    # Utilities
    "plugin.program.openwizard"
    "inputstream.adaptive"
    "script.module.inputstreamhelper"
    "plugin.video.youtube"
    # Skin dependencies (from kodiPkgs)
    "script.module.jurialmunkey"
    "script.module.infotagger"
  ];

  # SQL to enable only our managed addons and mark them as system-origin
  addonIdList = lib.concatMapStringsSep ", " (id: "'${id}'") managedAddonIds;
  enableAddonsSql =
    pkgs.writeText "kodi-enable-addons.sql"
    "UPDATE installed SET enabled = 1, disabledReason = 0, origin = '${originSystem}' WHERE addonID IN (${addonIdList});\n";

  # SQL to bootstrap a fresh Addons DB with managed addons pre-registered as enabled
  initAddonsSql = let
    now = "2000-01-01 00:00:00";
    mkInsert = id: "INSERT OR IGNORE INTO installed (addonID, enabled, installDate, lastUpdated, lastUsed, origin, disabledReason) VALUES ('${id}', 1, '${now}', '${now}', '${now}', '${originSystem}', 0);";
    inserts = lib.concatMapStringsSep "\n" mkInsert managedAddonIds;
    schema = lib.concatStringsSep "\n" [
      "CREATE TABLE IF NOT EXISTS version (idVersion integer, iCompressCount integer);"
      "INSERT OR IGNORE INTO version VALUES (33, 0);"
      "CREATE TABLE IF NOT EXISTS addons (id INTEGER PRIMARY KEY, metadata BLOB, addonID TEXT NOT NULL, version TEXT NOT NULL, name TEXT NOT NULL, summary TEXT NOT NULL, news TEXT NOT NULL, description TEXT NOT NULL);"
      "CREATE INDEX IF NOT EXISTS idxAddons ON addons(addonID);"
      "CREATE TABLE IF NOT EXISTS repo (id integer primary key, addonID text, checksum text, lastcheck text, version text, nextcheck TEXT);"
      "CREATE TABLE IF NOT EXISTS addonlinkrepo (idRepo integer, idAddon integer);"
      "CREATE UNIQUE INDEX IF NOT EXISTS ix_addonlinkrepo_1 ON addonlinkrepo (idAddon, idRepo);"
      "CREATE UNIQUE INDEX IF NOT EXISTS ix_addonlinkrepo_2 ON addonlinkrepo (idRepo, idAddon);"
      "CREATE TABLE IF NOT EXISTS update_rules (id integer primary key, addonID TEXT, updateRule INTEGER);"
      "CREATE UNIQUE INDEX IF NOT EXISTS idxUpdate_rules ON update_rules(addonID, updateRule);"
      "CREATE TABLE IF NOT EXISTS package (id integer primary key, addonID text, filename text, hash text);"
      "CREATE UNIQUE INDEX IF NOT EXISTS idxPackage ON package(filename);"
      "CREATE TABLE IF NOT EXISTS installed (id INTEGER PRIMARY KEY, addonID TEXT UNIQUE, enabled BOOLEAN, installDate TEXT, lastUpdated TEXT, lastUsed TEXT, origin TEXT NOT NULL DEFAULT '', disabledReason INTEGER NOT NULL DEFAULT 0);"
    ];
  in
    pkgs.writeText "kodi-init-addons.sql" "${schema}\n${inserts}\n";

  # Helper to update or create a setting in a Kodi settings.xml file
  updateKodiSetting = ''
    update_setting() {
      local file="$1" id="$2" value="$3"
      mkdir -p "$(dirname "$file")"
      if [ ! -f "$file" ]; then
        printf '<settings version="2">\n    <setting id="%s">%s</setting>\n</settings>\n' "$id" "$value" > "$file"
      elif grep -q "id=\"$id\"" "$file"; then
        ${pkgs.gnused}/bin/sed -i "s|<setting id=\"$id\"[^>]*>[^<]*</setting>|<setting id=\"$id\">$value</setting>|" "$file"
      else
        ${pkgs.gnused}/bin/sed -i "s|</settings>|    <setting id=\"$id\">$value</setting>\n</settings>|" "$file"
      fi
    }
  '';

  # Script that runs before every Kodi launch
  kodiPreLaunch = pkgs.writeShellScript "kodi-pre-launch" ''
    ${updateKodiSetting}
    GUISETTINGS="$HOME/.kodi/userdata/guisettings.xml"
    mkdir -p "$(dirname "$GUISETTINGS")"
    if [ ! -f "$GUISETTINGS" ]; then
      printf '<settings version="2">\n</settings>\n' > "$GUISETTINGS"
    fi
    update_setting "$GUISETTINGS" "addons.unknownsources" "true"
    update_setting "$GUISETTINGS" "general.addonnotifications" "false"
    update_setting "$GUISETTINGS" "addons.updatemode" "1"

    # Force skinvariables to regenerate shortcuts from JSON nodes on next skin load
    SKIN_SETTINGS="$HOME/.kodi/userdata/addon_data/skin.arctic.fuse.3/settings.xml"
    if [ -f "$SKIN_SETTINGS" ]; then
      ${pkgs.gnused}/bin/sed -i 's|<setting id="script-skinvariables-generator-hash"[^>]*>[^<]*</setting>|<setting id="script-skinvariables-generator-hash"></setting>|' "$SKIN_SETTINGS"
      ${pkgs.gnused}/bin/sed -i 's|<setting id="Shortcuts.RebuildDateTime"[^>]*>[^<]*</setting>|<setting id="Shortcuts.RebuildDateTime"></setting>|' "$SKIN_SETTINGS"
    fi

    KODI_DB_DIR="$HOME/.kodi/userdata/Database"
    mkdir -p "$KODI_DB_DIR"
    ADDONS_DB="$(ls "$KODI_DB_DIR"/Addons*.db 2>/dev/null | head -1)"
    if [ -z "$ADDONS_DB" ]; then
      # Fresh install: create DB with managed addons pre-registered as enabled
      ADDONS_DB="$KODI_DB_DIR/Addons33.db"
      ${pkgs.sqlite}/bin/sqlite3 "$ADDONS_DB" < ${initAddonsSql}
    else
      # Existing DB: enable our managed addons
      ${pkgs.sqlite}/bin/sqlite3 "$ADDONS_DB" < ${enableAddonsSql}
    fi
  '';

  # Wrapper script that runs pre-launch, execs Kodi, then cleans up zombies on exit
  kodiLauncher = pkgs.writeShellScript "kodi-launcher" ''
    ${kodiPreLaunch}
    export SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
    export CURL_CA_BUNDLE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
    export REQUESTS_CA_BUNDLE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
    export NIX_SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"

    ${kodiWithAddons}/bin/kodi "$@"
    # kodi-wayland often leaves zombie processes after Quit(); clean them up
    ${pkgs.procps}/bin/pkill -f 'kodi' 2>/dev/null || true
  '';

  kodiWrapped = pkgs.symlinkJoin {
    name = "kodi-wrapped";
    paths = [kodiWithAddons];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      rm "$out/bin/kodi"
      ln -s ${kodiLauncher} "$out/bin/kodi"
    '';
  };
in {
  imports = [
    ./widgets.nix
  ];

  config = lib.mkIf pkgs.stdenv.isLinux {
    programs.kodi = {
      enable = true;
      package = kodiWrapped;
    };

    # File manager sources for installing repos from zip
    home.file.".kodi/userdata/sources.xml".text = ''
      <sources>
          <programs>
              <default pathversion="1"></default>
          </programs>
          <video>
              <default pathversion="1"></default>
          </video>
          <music>
              <default pathversion="1"></default>
          </music>
          <pictures>
              <default pathversion="1"></default>
          </pictures>
          <files>
              <default pathversion="1"></default>
              <source>
                  <name>Umbrella Repo</name>
                  <path pathversion="1">https://umbrellaplug.github.io</path>
                  <allowsharing>true</allowsharing>
              </source>
              <source>
                  <name>FenLight Repo</name>
                  <path pathversion="1">https://fenlightanonymouse.github.io/packages</path>
                  <allowsharing>true</allowsharing>
              </source>
              <source>
                  <name>jurialmunkey Repo</name>
                  <path pathversion="1">https://jurialmunkey.github.io/repository.jurialmunkey/</path>
                  <allowsharing>true</allowsharing>
              </source>
              <source>
                  <name>CocoScrapers Repo</name>
                  <path pathversion="1">https://cocojoe2411.github.io</path>
                  <allowsharing>true</allowsharing>
              </source>
              <source>
                  <name>nixgates Repo</name>
                  <path pathversion="1">https://nixgates.github.io/packages</path>
                  <allowsharing>true</allowsharing>
              </source>
          </files>
      </sources>
    '';

    # Copy skin to writable location so skinvariables can generate XML includes
    home.activation.kodiSkin = lib.hm.dag.entryAfter ["writeBoundary"] ''
      SKIN_SRC="${customAddons.arcticFuseSkin}/share/kodi/addons/skin.arctic.fuse.3"
      SKIN_DST="${config.home.homeDirectory}/.kodi/addons/skin.arctic.fuse.3"
      if [ -d "$SKIN_SRC" ]; then
        rm -rf "$SKIN_DST"
        cp -a "$SKIN_SRC" "$SKIN_DST"
        chmod -R u+w "$SKIN_DST"

        # Patch spotlight defaults: TMDb trending instead of RandomMovies
        ${pkgs.gnused}/bin/sed -i \
          's|Skin.SetString(HomeSwitcher.Home.Spotlight.Path,special://skin/extras/playlists/RandomMovies.xsp)|Skin.SetString(HomeSwitcher.Home.Spotlight.Path,plugin://plugin.video.themoviedb.helper/?info=trending_day\&tmdb_type=both\&widget=true\&next_page=true)|' \
          "$SKIN_DST/shortcuts/skinvariables-startup.json"
        ${pkgs.gnused}/bin/sed -i \
          's|Skin.SetString(HomeSwitcher.Home.Spotlight.Label,Random Movies)|Skin.SetString(HomeSwitcher.Home.Spotlight.Label,Trending)",\n                        "Skin.SetBool(Spotlight.EnableSlide)|' \
          "$SKIN_DST/shortcuts/skinvariables-startup.json"
      fi
    '';

    # Pre-enable addons if DB already exists (e.g. after Kodi's first run)
    home.activation.kodiEnableAddons = lib.hm.dag.entryAfter ["writeBoundary" "kodiSkin"] ''
      KODI_DB_DIR="${config.home.homeDirectory}/.kodi/userdata/Database"
      ADDONS_DB="$(ls "$KODI_DB_DIR"/Addons*.db 2>/dev/null | head -1)"
      if [ -n "$ADDONS_DB" ]; then
        ${pkgs.sqlite}/bin/sqlite3 "$ADDONS_DB" < ${enableAddonsSql}
      fi
    '';

    # Inject addon secrets
    home.activation.kodiSecrets = lib.hm.dag.entryAfter ["writeBoundary" "sops-nix"] ''
      ${updateKodiSetting}
      GUISETTINGS="${config.home.homeDirectory}/.kodi/userdata/guisettings.xml"
      mkdir -p "$(dirname "$GUISETTINGS")"
      if [ ! -f "$GUISETTINGS" ]; then
        printf '<settings version="2">\n    <setting id="lookandfeel.skin">skin.arctic.fuse.3</setting>\n</settings>\n' > "$GUISETTINGS"
      fi
      update_setting "$GUISETTINGS" "lookandfeel.skin" "skin.arctic.fuse.3"

      # Allow third-party addons without per-addon confirmation prompts
      update_setting "$GUISETTINGS" "addons.unknownsources" "true"
      update_setting "$GUISETTINGS" "general.addonnotifications" "false"
      # Allow official addons to be updated from any repository
      update_setting "$GUISETTINGS" "addons.updatemode" "1"

      # ── Real-Debrid ──
      RD_TOKEN_FILE="${config.sops.secrets."realdebrid_token".path}"
      if [ -f "$RD_TOKEN_FILE" ]; then
        RD_TOKEN="$(cat "$RD_TOKEN_FILE")"

        # Umbrella
        update_setting "${kodiAddonData}/plugin.video.umbrella/settings.xml" \
          "realdebridtoken" "$RD_TOKEN"
        update_setting "${kodiAddonData}/plugin.video.umbrella/settings.xml" \
          "realdebrid.enable" "true"

        # Seren
        update_setting "${kodiAddonData}/plugin.video.seren/settings.xml" \
          "rd.auth" "$RD_TOKEN"
        update_setting "${kodiAddonData}/plugin.video.seren/settings.xml" \
          "realdebrid.enabled" "true"

        # FenLight
        update_setting "${kodiAddonData}/plugin.video.fenlight/settings.xml" \
          "fenlight.rd.token" "$RD_TOKEN"
      fi
    '';
  };
}
