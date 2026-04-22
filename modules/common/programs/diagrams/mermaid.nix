# Mermaid tooling:
#   - mermaid-cli (`mmdc`) for offline .mmd → svg/png/pdf rendering
#   - `mermaid-live` launcher that opens the containerised Mermaid Live Editor
#     at http://localhost:8898 in an app-mode window. Container lives in
#     modules/containers/mermaid-live.nix.
#   - When called with a .mmd file (via xdg-open or directly), the diagram
#     source is deflated and base64url-encoded into the URL fragment using
#     the standard mermaid.live `pako:` format, so the editor opens with the
#     diagram pre-loaded.
{
  pkgs,
  lib,
  ...
}: let
  url = "http://localhost:8898";

  # Python one-liner that reads Mermaid source on stdin and emits the
  # `pako:`-encoded deep link expected by Mermaid Live Editor. Same format
  # used by mermaid.live's own "Edit diagram" share URLs.
  encodeScript = pkgs.writeText "mermaid-encode.py" ''
    import sys, json, zlib, base64
    code = sys.stdin.read()
    blob = json.dumps({
      "code": code,
      "mermaid": '{"theme":"default"}',
      "autoSync": True,
      "rough": False,
      "updateDiagram": False,
      "panZoom": True,
    })
    compressed = zlib.compress(blob.encode(), 9)
    encoded = base64.urlsafe_b64encode(compressed).decode().rstrip("=")
    sys.stdout.write("pako:" + encoded)
  '';

  mermaidLiveLauncher = pkgs.writeShellApplication {
    name = "mermaid-live";
    runtimeInputs = [pkgs.xdg-utils pkgs.python3];
    text = ''
      target="${url}"
      if [ $# -ge 1 ] && [ -r "$1" ]; then
        frag=$(python3 ${encodeScript} < "$1")
        target="${url}/edit#$frag"
      fi

      if command -v chromium >/dev/null 2>&1; then
        exec chromium --app="$target"
      elif command -v google-chrome-stable >/dev/null 2>&1; then
        exec google-chrome-stable --app="$target"
      else
        exec xdg-open "$target"
      fi
    '';
  };

  mermaidLiveDesktop = pkgs.makeDesktopItem {
    name = "mermaid-live";
    desktopName = "Mermaid Live Editor";
    comment = "Live editor for Mermaid diagrams (local container)";
    # %f passes the file path when opened via xdg-open / file manager.
    exec = "${mermaidLiveLauncher}/bin/mermaid-live %f";
    icon = "applications-graphics";
    categories = ["Graphics" "Development"];
    terminal = false;
    mimeTypes = ["text/vnd.mermaid"];
  };
in {
  home.packages =
    [pkgs.mermaid-cli]
    ++ lib.optionals pkgs.stdenv.isLinux [
      mermaidLiveLauncher
      mermaidLiveDesktop
    ];

  # Deterministic path for tools that want to shell out to mmdc (neovim
  # renderers, scripts in ./scripts/, etc.).
  home.sessionVariables.MERMAID_CLI = "${pkgs.mermaid-cli}/bin/mmdc";
}
