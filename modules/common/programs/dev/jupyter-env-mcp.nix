# Jupyter MCP stack — two cooperating servers:
#
#   jupyter-env  — local custom MCP. Owns Python env provisioning (uv-managed
#                  venvs registered as ipykernels) and the JupyterLab process
#                  lifecycle. Source under packages/jupyter-env-mcp/.
#
#   jupyter      — datalayer/jupyter-mcp-server upstream (git-pinned). Reads/
#                  writes/executes notebook cells in the running JupyterLab.
#                  Reads JUPYTER_URL / JUPYTER_TOKEN from the runtime config
#                  file (~/.cache/jupyter-mcp/server.json) that jupyter-env's
#                  start_jupyter tool writes.
#
# Both are registered directly here (outside mcp-servers.nix) because the
# pair shares lifecycle wiring that the registry's catalog/git-source schema
# doesn't model — same precedent as code-index.nix.
#
# To bump datalayer rev:
#   git ls-remote https://github.com/datalayer/jupyter-mcp-server HEAD
#   nix-prefetch-github datalayer jupyter-mcp-server --rev <sha>
{
  pkgs,
  lib,
  inputs,
  ...
}: let
  jupyter-env-mcp = import ../../../../packages/jupyter-env-mcp/package.nix {
    inherit pkgs;
    inherit (pkgs) lib;
    inherit (inputs) uv2nix pyproject-nix pyproject-build-systems;
  };

  datalayerSrc = pkgs.fetchFromGitHub {
    owner = "datalayer";
    repo = "jupyter-mcp-server";
    rev = "e6cfd4924ba34b2f381a1730c96dce30cf57667c";
    hash = "sha256-4fKpVHtRvecbGZrtVRVHxMvvAt0RvjmUx9b63X7MK6w=";
  };

  # Key the writable workdir on the store-path hash, so rev bumps invalidate
  # the cached venv (same pattern as mkGitServer in claude.nix).
  srcKey = builtins.substring 0 12 (baseNameOf "${datalayerSrc}");

  # Wrapper for the upstream datalayer server. Sources JUPYTER_URL/TOKEN from
  # the runtime config jupyter-env writes. uv resolves deps into a writable
  # cache dir on first run.
  #
  # Claude Code spawns every MCP server at startup, before anyone can call
  # `jupyter-env.start_jupyter` to materialise the runtime config. If we exit
  # on missing config the server is marked failed and never recovers. Boot
  # with placeholders instead so tools register; calls fail later if Jupyter
  # still isn't running by tool-invocation time.
  jupyter-mcp-wrapper = pkgs.writeShellApplication {
    name = "mcp-jupyter";
    runtimeInputs = with pkgs; [uv jq];
    text = ''
      cfg="''${XDG_CACHE_HOME:-$HOME/.cache}/jupyter-mcp/server.json"
      if [ -f "$cfg" ]; then
        JUPYTER_URL="$(jq -r .url "$cfg")"
        JUPYTER_TOKEN="$(jq -r .token "$cfg")"
      else
        JUPYTER_URL="http://127.0.0.1:0"
        JUPYTER_TOKEN="pending-start_jupyter"
      fi
      export JUPYTER_URL JUPYTER_TOKEN

      workdir="''${XDG_CACHE_HOME:-$HOME/.cache}/mcp-servers/jupyter-${srcKey}"
      if [ ! -e "$workdir/.ready" ]; then
        mkdir -p "$workdir"
        cp -rL --no-preserve=mode,ownership "${datalayerSrc}/." "$workdir/"
        touch "$workdir/.ready"
      fi
      cd "$workdir"
      exec uv run jupyter-mcp-server "$@"
    '';
  };

  # JupyterLab bundled with jupyter-collaboration (RTC) and a curated set of
  # extensions. RTC is required so the Datalayer `jupyter` MCP's on-disk
  # notebook edits propagate to any open browser tab live — without collab,
  # the frontend only picks up changes on reload.
  jupyterlab-rtc = pkgs.python3.withPackages (ps: [
    ps.jupyterlab
    ps.jupyter-collaboration
    ps.ipykernel
    ps.jupyterlab-lsp
    ps.python-lsp-server
  ]);

  # Dir containing overrides.json (dark theme + 60s autosave). LabApp reads
  # this directly from `app_settings_dir`, which we redirect via the config
  # file below — can't use $JUPYTERLAB_DIR because the nixpkgs jupyter-lab
  # wrapper force-exports it to its own store path, clobbering anything we
  # set.
  jupyterlab-settings-dir = pkgs.writeTextFile {
    name = "jupyterlab-settings-dir";
    destination = "/overrides.json";
    text = builtins.toJSON {
      "@jupyterlab/apputils-extension:themes" = {
        theme = "JupyterLab Dark";
      };
      "@jupyterlab/docmanager-extension:plugin" = {
        autosave = true;
        autosaveInterval = 60;
      };
    };
  };

  # jupyter_lab_config.py pointing LabApp.app_settings_dir at the overrides
  # dir. Placed in a dir exposed via $JUPYTER_CONFIG_PATH so jupyter_core
  # discovers it at startup.
  jupyterlab-config-dir = pkgs.writeTextFile {
    name = "jupyterlab-config-dir";
    destination = "/jupyter_lab_config.py";
    text = ''
      c.LabApp.app_settings_dir = "${jupyterlab-settings-dir}"
    '';
  };

  # Wrapper for jupyter-env: ensures uv (env provisioning), jupyter (lab
  # launch + kernelspec mgmt, with RTC), and xdg-open (browser) are on PATH.
  # JUPYTER_CONFIG_PATH lets jupyter_core pick up our lab config so the dark
  # theme and autosave defaults apply to every lab instance.
  jupyter-env-wrapper = pkgs.writeShellApplication {
    name = "mcp-jupyter-env";
    runtimeInputs = [pkgs.uv jupyterlab-rtc pkgs.xdg-utils];
    text = ''
      export JUPYTER_CONFIG_PATH="${jupyterlab-config-dir}''${JUPYTER_CONFIG_PATH:+:$JUPYTER_CONFIG_PATH}"
      exec ${jupyter-env-mcp}/bin/jupyter-env-mcp "$@"
    '';
  };
in {
  programs.claude-code.mcpServers = {
    jupyter-env.command = lib.getExe jupyter-env-wrapper;
    jupyter.command = lib.getExe jupyter-mcp-wrapper;
  };
}
