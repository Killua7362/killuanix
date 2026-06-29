{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  dmsRoot = "${inputs.dms}/quickshell";
  qtQmlPath = "${pkgs.kdePackages.qtdeclarative}/lib/qt-6/qml";
in {
  home.packages = [pkgs.kdePackages.qtdeclarative];

  # Synthesize a qmldir-rooted import tree under ~/.cache/qml-workspace/qs/
  # mirroring ${dms}/quickshell/. Quickshell resolves `import qs.Common` at
  # runtime against the shell root; stock qmlls6 needs real qmldir files at
  # `<importPath>/qs/Common/qmldir` to provide completion. We generate those
  # qmldirs from the .qml filenames in each DMS dir and symlink the originals.
  home.activation.qmlWorkspaceImportTree = lib.hm.dag.entryAfter ["writeBoundary"] ''
    set -eu
    cache="$HOME/.cache/qml-workspace"
    rm -rf "$cache/qs"
    mkdir -p "$cache"
    printf '%s\n' "${qtQmlPath}" > "$cache/QT_QML_PATH"

    build_module() {
      local src="$1" dst="$2" mod="$3"
      mkdir -p "$dst"
      local qmldir="$dst/qmldir"
      printf 'module %s\n' "$mod" > "$qmldir"
      local f base type
      for f in "$src"/*.qml; do
        [ -e "$f" ] || continue
        base="$(basename "$f")"
        type="''${base%.qml}"
        case "$type" in
          [A-Z]*) ;;
          *) continue ;;
        esac
        ln -sfn "$f" "$dst/$base"
        if head -n1 "$f" | grep -q '^pragma Singleton'; then
          printf 'singleton %s 1.0 %s\n' "$type" "$base" >> "$qmldir"
        else
          printf '%s 1.0 %s\n' "$type" "$base" >> "$qmldir"
        fi
      done
      local sub subname
      for sub in "$src"/*/; do
        [ -d "$sub" ] || continue
        subname="$(basename "$sub")"
        case "$subname" in
          [A-Z]*) build_module "''${sub%/}" "$dst/$subname" "$mod.$subname" ;;
        esac
      done
    }

    build_module "${dmsRoot}" "$cache/qs" "qs"
  '';
}
