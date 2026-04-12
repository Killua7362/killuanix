# Custom Kodi addon derivations not available in nixpkgs
{
  pkgs,
  lib,
  kodiPlatform,
}: let
  kodiPkgs = kodiPlatform.packages;
in {
  # ── Skin ──
  arcticFuseSkin = kodiPkgs.buildKodiAddon rec {
    pname = "arctic-fuse-3";
    namespace = "skin.arctic.fuse.3";
    version = "3.1.17";

    src = pkgs.fetchFromGitHub {
      owner = "jurialmunkey";
      repo = "skin.arctic.fuse.3";
      tag = "v${version}";
      hash = "sha256-ftRZWia9byHoL6vRCscxqGwIpdwbGUsMNXb/h2QpVgs=";
    };

    meta = {
      homepage = "https://github.com/jurialmunkey/skin.arctic.fuse.3";
      description = "Arctic Fuse 3 skin for Kodi";
      platforms = lib.platforms.all;
      license = lib.licenses.gpl2Only;
    };
  };

  # ── Skin dependencies ──
  skinvariables = kodiPkgs.buildKodiAddon rec {
    pname = "skinvariables";
    namespace = "script.skinvariables";
    version = "2.1.35";

    src = pkgs.fetchFromGitHub {
      owner = "jurialmunkey";
      repo = "script.skinvariables";
      tag = "v${version}";
      hash = "sha256-AurclbDrf4aoBn3pphCvALKIHwkDh/7GVPAJuaD2Ej8=";
    };

    propagatedBuildInputs = with kodiPkgs; [
      jurialmunkey
      infotagger
    ];

    passthru.pythonPath = "resources/lib";

    meta = {
      homepage = "https://github.com/jurialmunkey/script.skinvariables";
      description = "Skin Variables helper for Kodi skins";
      platforms = lib.platforms.all;
      license = lib.licenses.gpl2Only;
    };
  };

  # ── Video addons ──
  tmdb-helper = kodiPkgs.buildKodiAddon rec {
    pname = "tmdb-helper";
    namespace = "plugin.video.themoviedb.helper";
    version = "6.15.1";

    src = pkgs.fetchFromGitHub {
      owner = "jurialmunkey";
      repo = "plugin.video.themoviedb.helper";
      tag = "v${version}";
      hash = "sha256-u+v6+XDQsZwtotAW087VRHh1AdUghQupqSah1gpx8Ts=";
    };

    meta = {
      homepage = "https://github.com/jurialmunkey/plugin.video.themoviedb.helper";
      description = "TMDb Helper for Kodi";
      platforms = lib.platforms.all;
      license = lib.licenses.gpl2Only;
    };
  };

  umbrella = kodiPkgs.buildKodiAddon {
    pname = "umbrella";
    namespace = "plugin.video.umbrella";
    version = "6.7.58";

    src = pkgs.fetchurl {
      url = "https://github.com/umbrellaplug/umbrellaplug.github.io/raw/master/omega/zips/plugin.video.umbrella/plugin.video.umbrella-6.7.62.zip";
      hash = "sha256-ybRnLn2MQtzmllUnaSFo5egfZaodXEOxmpbz3G5/c9c=";
    };

    sourceRoot = "plugin.video.umbrella";
    nativeBuildInputs = [pkgs.unzip];

    meta = {
      homepage = "https://github.com/umbrellaplug/umbrellaplug.github.io";
      description = "Umbrella video addon for Kodi";
      platforms = lib.platforms.all;
      license = lib.licenses.gpl2Only;
    };
  };

  fenlight = kodiPkgs.buildKodiAddon {
    pname = "fenlight";
    namespace = "plugin.video.fenlight";
    version = "2.2.11";

    src = pkgs.fetchurl {
      url = "https://github.com/thejason40/FenLightPlus/raw/main/packages/plugin.video.fenlight-2.2.11.zip";
      hash = "sha256-ugyCMpeLpV8lDBQEQqRMWiR7fVniLYxvbl7QGFfx1DM=";
    };

    sourceRoot = "plugin.video.fenlight";
    nativeBuildInputs = [pkgs.unzip];

    meta = {
      homepage = "https://github.com/thejason40/FenLightPlus";
      description = "FenLight+ video addon for Kodi";
      platforms = lib.platforms.all;
      license = lib.licenses.gpl2Only;
    };
  };

  # ── Seren and dependencies ──
  seren = {
    context-seren,
    unidecode,
    beautifulsoup4,
    myconnpy,
  }:
    kodiPkgs.buildKodiAddon {
      pname = "seren";
      namespace = "plugin.video.seren";
      version = "3.0.1";

      src = pkgs.fetchFromGitHub {
        owner = "nixgates";
        repo = "plugin.video.seren";
        rev = "b4f4b63bf59b38b93bd565a8503e121f64c91e30";
        hash = "sha256-Bxd0YvLiTJQaLfZe1juLS/tokSFBgco73A3ts3Sdm+Q=";
      };

      propagatedBuildInputs = [
        unidecode
        beautifulsoup4
        context-seren
        myconnpy
      ];

      meta = {
        homepage = "https://github.com/nixgates/plugin.video.seren";
        description = "Seren video addon for Kodi";
        platforms = lib.platforms.all;
        license = lib.licenses.gpl2Only;
      };
    };

  context-seren = kodiPkgs.buildKodiAddon {
    pname = "context-seren";
    namespace = "context.seren";
    version = "3.0.1";

    src = pkgs.fetchFromGitHub {
      owner = "SerenKodi";
      repo = "context.seren";
      rev = "0094a1e957c8c504b228f2d381de5be576acd567";
      hash = "sha256-1eDlcoQPTW5GYBwnphxSuuPt3ql6WYs+SoNhwi3xSw0=";
    };

    meta = {
      homepage = "https://github.com/SerenKodi/context.seren";
      description = "Context menu addon for Seren";
      platforms = lib.platforms.all;
      license = lib.licenses.gpl2Only;
    };
  };

  unidecode = kodiPkgs.buildKodiAddon {
    pname = "unidecode";
    namespace = "script.module.unidecode";
    version = "1.3.6";

    src = pkgs.fetchurl {
      url = "https://mirrors.kodi.tv/addons/omega/script.module.unidecode/script.module.unidecode-1.3.6.zip";
      hash = "sha256-9mJXc2ACtHn54QklnWkRE0EqfyIVE5qlU015XY1pJac=";
    };

    sourceRoot = "script.module.unidecode";
    nativeBuildInputs = [pkgs.unzip];

    meta = {
      homepage = "https://mirrors.kodi.tv/addons/omega/script.module.unidecode/";
      description = "Unidecode module for Kodi (Omega)";
      platforms = lib.platforms.all;
      license = lib.licenses.gpl2Only;
    };
  };

  beautifulsoup4 = {soupsieve}:
    kodiPkgs.buildKodiAddon {
      pname = "beautifulsoup4";
      namespace = "script.module.beautifulsoup4";
      version = "4.12.2";

      src = pkgs.fetchurl {
        url = "https://mirrors.kodi.tv/addons/omega/script.module.beautifulsoup4/script.module.beautifulsoup4-4.12.2.zip";
        hash = "sha256-IOflbJ8ldbw5d7fRyHWkpWFjt4mkwIilYdmI9MZP080=";
      };

      propagatedBuildInputs = [soupsieve];
      sourceRoot = "script.module.beautifulsoup4";
      nativeBuildInputs = [pkgs.unzip];

      meta = {
        homepage = "https://mirrors.kodi.tv/addons/omega/script.module.beautifulsoup4/";
        description = "BeautifulSoup4 module for Kodi (Omega)";
        platforms = lib.platforms.all;
        license = lib.licenses.mit;
      };
    };

  soupsieve = kodiPkgs.buildKodiAddon {
    pname = "soupsieve";
    namespace = "script.module.soupsieve";
    version = "2.4.1";

    src = pkgs.fetchurl {
      url = "https://mirrors.kodi.tv/addons/omega/script.module.soupsieve/script.module.soupsieve-2.4.1.zip";
      hash = "sha256-3YyPF8PI6Kh7cA0sB29ncagbCOO6MTu1xk3cFQB4jYs=";
    };

    sourceRoot = "script.module.soupsieve";
    nativeBuildInputs = [pkgs.unzip];

    meta = {
      homepage = "https://mirrors.kodi.tv/addons/omega/script.module.soupsieve/";
      description = "SoupSieve CSS selector module for Kodi (Omega)";
      platforms = lib.platforms.all;
      license = lib.licenses.mit;
    };
  };

  myconnpy = kodiPkgs.buildKodiAddon {
    pname = "myconnpy";
    namespace = "script.module.myconnpy";
    version = "8.0.33";

    src = pkgs.fetchurl {
      url = "https://mirrors.kodi.tv/addons/omega/script.module.myconnpy/script.module.myconnpy-8.0.33.zip";
      hash = "sha256-NjcOkEue1Z3JYVbp1Nl+Pehrmy2ZiAs/rJ+MJ4rtJJ4=";
    };

    sourceRoot = "script.module.myconnpy";
    nativeBuildInputs = [pkgs.unzip];

    meta = {
      homepage = "https://mirrors.kodi.tv/addons/omega/script.module.myconnpy/";
      description = "MySQL Connector Python module for Kodi (Omega)";
      platforms = lib.platforms.all;
      license = lib.licenses.gpl2Only;
    };
  };

  # ── Scrapers ──
  cocoscrapers = kodiPkgs.buildKodiAddon {
    pname = "cocoscrapers";
    namespace = "script.module.cocoscrapers";
    version = "1.0.32";

    src = pkgs.fetchurl {
      url = "https://github.com/CocoJoe2411/repository.cocoscrapers/raw/main/zips/script.module.cocoscrapers/script.module.cocoscrapers-1.0.32.zip";
      hash = "sha256-8zsR4/zIlnrsplVIOYISunyAYpiEXqwuV7o4zTWmQ24=";
    };

    sourceRoot = "script.module.cocoscrapers";
    nativeBuildInputs = [pkgs.unzip];

    meta = {
      homepage = "https://github.com/CocoJoe2411/repository.cocoscrapers";
      description = "CocoScrapers scraper module for Kodi";
      platforms = lib.platforms.all;
      license = lib.licenses.gpl2Only;
    };
  };

  # ── Tracking ──
  simkl = kodiPkgs.buildKodiAddon rec {
    pname = "simkl";
    namespace = "script.simkl";
    version = "3.2.2";

    src = pkgs.fetchFromGitHub {
      owner = "SIMKL";
      repo = "script.simkl";
      tag = version;
      hash = "sha256-zmnw7wrY6LSC4LYbzlxN9lOf1U7cSfAd49ZN+XiWrF4=";
    };

    meta = {
      homepage = "https://github.com/SIMKL/script.simkl";
      description = "Simkl tracking addon for Kodi";
      platforms = lib.platforms.all;
      license = lib.licenses.gpl2Only;
    };
  };

  # ── Utilities ──
  openwizard = kodiPkgs.buildKodiAddon rec {
    pname = "openwizard";
    namespace = "plugin.program.openwizard";
    version = "2.0.7";

    src = pkgs.fetchFromGitHub {
      owner = "a4k-openproject";
      repo = "plugin.program.openwizard";
      tag = version;
      hash = "sha256-i1CPXk8E2N7+FwUITQ5EBkK/KIg842rKyykkRvtWExU=";
    };

    meta = {
      homepage = "https://github.com/a4k-openproject/plugin.program.openwizard";
      description = "Open Wizard maintenance tool for Kodi";
      platforms = lib.platforms.all;
      license = lib.licenses.gpl2Only;
    };
  };

  # ── Repositories ──
  repo-umbrella = kodiPkgs.buildKodiAddon {
    pname = "repository-umbrella";
    namespace = "repository.umbrella";
    version = "2.2.6";

    src = pkgs.fetchurl {
      url = "https://umbrellaplug.github.io/repository.umbrella-2.2.6.zip";
      hash = "sha256-BVEF4Ax9oJDMEklHvFxenNrjEPhof8TBb4PVG4l1ASg=";
    };

    sourceRoot = "repository.umbrellaplug.github.io";
    nativeBuildInputs = [pkgs.unzip];

    meta = {
      homepage = "https://umbrellaplug.github.io";
      description = "Umbrella addon repository for Kodi";
      platforms = lib.platforms.all;
      license = lib.licenses.gpl2Only;
    };
  };

  repo-jurialmunkey = kodiPkgs.buildKodiAddon {
    pname = "repository-jurialmunkey";
    namespace = "repository.jurialmunkey";
    version = "3.4";

    src = pkgs.fetchurl {
      url = "https://jurialmunkey.github.io/repository.jurialmunkey/repository.jurialmunkey-3.4.zip";
      hash = "sha256-lyuovaDdFhCKFgFTTlR6d0Ui1zzSx5Gc5lGi0yr3o/0=";
    };

    sourceRoot = "repository.jurialmunkey";
    nativeBuildInputs = [pkgs.unzip];

    meta = {
      homepage = "https://jurialmunkey.github.io/repository.jurialmunkey/";
      description = "jurialmunkey addon repository for Kodi";
      platforms = lib.platforms.all;
      license = lib.licenses.gpl2Only;
    };
  };

  repo-cocoscrapers = kodiPkgs.buildKodiAddon {
    pname = "repository-cocoscrapers";
    namespace = "repository.cocoscrapers";
    version = "1.0.1";

    src = pkgs.fetchurl {
      url = "https://cocojoe2411.github.io/repository.cocoscrapers-1.0.1.zip";
      hash = "sha256-4nqb8ey+HTYiIgsXEA+LqvI+qz8YDJBL7mVyWxXJ3LY=";
    };

    sourceRoot = "repository.cocoscrapers";
    nativeBuildInputs = [pkgs.unzip];

    meta = {
      homepage = "https://cocojoe2411.github.io";
      description = "CocoScrapers addon repository for Kodi";
      platforms = lib.platforms.all;
      license = lib.licenses.gpl2Only;
    };
  };

  repo-nixgates = kodiPkgs.buildKodiAddon {
    pname = "repository-nixgates";
    namespace = "repository.nixgates";
    version = "2.2.0";

    src = pkgs.fetchurl {
      url = "https://nixgates.github.io/packages/repository.nixgates-2.2.0.zip";
      hash = "sha256-F91/eccJe3xcofsjUAjKNo7ZhudmiBrf2r6RvkuDAW8=";
    };

    sourceRoot = "repository.nixgates";
    nativeBuildInputs = [pkgs.unzip];

    meta = {
      homepage = "https://nixgates.github.io/packages";
      description = "nixgates (Seren) addon repository for Kodi";
      platforms = lib.platforms.all;
      license = lib.licenses.gpl2Only;
    };
  };
}
