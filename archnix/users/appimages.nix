{ config, lib, pkgs, ... }:

let
  cfg = config.myAppImages;
in
{
  options.myAppImages = {
    enable = lib.mkEnableOption "Enable AppImage runner declarations";

    directory = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/Applications";
      description = "Where AppImages will be cached.";
    };

    apps = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule ({ ... }: {
        options = {
          repoOwner  = lib.mkOption { type = lib.types.str; };
          repoName   = lib.mkOption { type = lib.types.str; };
          releaseTag = lib.mkOption { type = lib.types.str; };
          fileName   = lib.mkOption { type = lib.types.str; };
        };
      }));
      default = { };
      description = "Map of AppImage apps keyed by their launch command.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Install wrappers so you can type app name directly to run the AppImage
    home.packages = builtins.attrValues (lib.mapAttrs (name: appCfg:
      pkgs.writeShellScriptBin name "${cfg.directory}/${appCfg.fileName} \"$@\""
    ) cfg.apps);

    # Activation step handles downloading + integration
    home.activation.appimages = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      echo "==> Installing AppImages…"

      # Ensure directories exist
      mkdir -p "${cfg.directory}"
      mkdir -p "${config.xdg.dataHome}/applications"

      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (appName: appCfg: ''
        target="${cfg.directory}/${appCfg.fileName}"
        url="https://github.com/${appCfg.repoOwner}/${appCfg.repoName}/releases/download/${appCfg.releaseTag}/${appCfg.fileName}"

        if [ ! -f "$target" ]; then
          echo "[${appName}] Downloading $url → $target"
          if ! /usr/bin/curl -L --fail --progress-bar -o "$target" "$url"; then
            echo "WARNING: Failed to download $url" >&2
            echo "         ${appName} will not run until you provide the AppImage at $target" >&2
            continue
          fi
          chmod +x "$target"
        else
          echo "[${appName}] Already installed at $target"
        fi
      '') cfg.apps)}
    '';
  };
}
