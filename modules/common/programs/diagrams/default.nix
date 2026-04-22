# Diagram authoring tooling (Excalidraw + Mermaid) — container-backed web UIs
# with Home Manager launchers, xdg-open-compatible MIME handling, and MCP
# server integration (see ../dev/claude.nix).
{
  pkgs,
  lib,
  ...
}: let
  # Shared MIME info registering the file extensions these apps handle. Lands
  # in ~/.nix-profile/share/mime/packages/ where update-mime-database picks it
  # up (HM runs that automatically when xdg.mime.enable is true, which it is
  # via cross-platform/default.nix).
  diagramsMimeInfo = pkgs.writeTextDir "share/mime/packages/diagrams.xml" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
      <mime-type type="text/vnd.mermaid">
        <comment>Mermaid diagram source</comment>
        <sub-class-of type="text/plain"/>
        <glob pattern="*.mmd"/>
        <glob pattern="*.mermaid"/>
      </mime-type>
    </mime-info>
  '';
in {
  imports = [
    ./excalidraw.nix
    ./mermaid.nix
  ];

  home.packages = lib.optionals pkgs.stdenv.isLinux [diagramsMimeInfo];
}
