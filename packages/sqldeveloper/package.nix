# Oracle SQL Developer 24.3.x — public download, unfree license.
#
# Used to connect to the DA dev Oracle DB through `bastion-sql` (see
# modules/common/programs/cloud/azure-bastion/). No bundled JRE — we
# point JAVA_HOME at nixpkgs JDK 17 at wrapper time.
{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
  unzip,
  temurin-bin-17,
  bash,
}: let
  jdk = temurin-bin-17;
in
  stdenv.mkDerivation rec {
    pname = "sqldeveloper";
    version = "24.3.1.347.1826";

    src = fetchurl {
      url = "https://download.oracle.com/otn_software/java/sqldeveloper/sqldeveloper-${version}-no-jre.zip";
      hash = "sha256-M5DvWJcvHyVQd8SeZrFxuGZHc7sW43Vwp8oWrMWvuMs=";
    };

    nativeBuildInputs = [unzip makeWrapper copyDesktopItems];

    dontBuild = true;
    dontConfigure = true;

    unpackPhase = ''
      runHook preUnpack
      unzip -q $src
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/opt $out/bin $out/share/pixmaps
      mv sqldeveloper $out/opt/sqldeveloper

      # Launcher uses bash, prepend interpreter path.
      chmod +x $out/opt/sqldeveloper/sqldeveloper.sh
      patchShebangs $out/opt/sqldeveloper/sqldeveloper.sh

      makeWrapper $out/opt/sqldeveloper/sqldeveloper.sh $out/bin/sqldeveloper \
        --set JAVA_HOME ${jdk} \
        --prefix PATH : ${lib.makeBinPath [jdk bash]}

      # Icon: SQL Developer ships a .png in the launcher dir.
      if [ -f $out/opt/sqldeveloper/icon.png ]; then
        install -Dm644 $out/opt/sqldeveloper/icon.png $out/share/pixmaps/sqldeveloper.png
      elif [ -f $out/opt/sqldeveloper/sqldeveloper/bin/sqldeveloper.png ]; then
        install -Dm644 $out/opt/sqldeveloper/sqldeveloper/bin/sqldeveloper.png $out/share/pixmaps/sqldeveloper.png
      fi

      runHook postInstall
    '';

    desktopItems = [
      (makeDesktopItem {
        name = "sqldeveloper";
        desktopName = "Oracle SQL Developer";
        comment = "Database IDE for Oracle";
        exec = "sqldeveloper";
        icon = "sqldeveloper";
        categories = ["Development" "Database"];
      })
    ];

    meta = {
      description = "Oracle SQL Developer ${version} — Database IDE";
      homepage = "https://www.oracle.com/database/sqldeveloper/";
      license = lib.licenses.unfree;
      platforms = ["x86_64-linux"];
      mainProgram = "sqldeveloper";
    };
  }
