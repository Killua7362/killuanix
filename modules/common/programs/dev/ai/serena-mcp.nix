{
  pkgs,
  lib,
  ...
}: let
  # oraios/serena — LSP-backed semantic code MCP. Unlike Claude Code's native
  # LSP (passive diagnostics only), Serena exposes symbol tools the model can
  # CALL: find_symbol, find_referencing_symbols, go-to-definition, and
  # symbol-level edits (rename / insert / replace-body). Fills the gap the
  # `jdtls-lsp` plugin could not — callable type-exact navigation + editing.
  #
  # No PyPI release we pin here; upstream ships via git, run with uv's tool
  # runner: `uvx --from git+… serena start-mcp-server`. `--context ide-assistant`
  # is Serena's Claude-Code-optimised toolset; `--project-from-cwd` scopes it to
  # the dir Claude Code launches the server in (= the project root).
  #
  # Java uses **upstream-jdtls mode** so Serena reuses the SAME mason jdtls +
  # lombok neovim uses (no ~500MB self-download). Those paths + the JDK 21 home
  # live in each project's `.serena/project.yml` (`ls_specific_settings.java`);
  # JAVA_HOME here is the fallback the docs describe if that key is unset.
  serenaWrapper = pkgs.writeShellApplication {
    name = "mcp-serena";
    runtimeInputs = [pkgs.uv];
    text = ''
      export UV_CACHE_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/mcp-uvx/uv-cache"
      mkdir -p "$UV_CACHE_DIR"
      # JDK 21 for the jdtls Serena launches (login shell pins Java 8 = ATG
      # target, which cannot run jdtls). project.yml java_home wins if set.
      export JAVA_HOME="/nix/store/c3pl7bqrx3d2rc3dh98z6yaj0mv1p52g-openjdk-21.0.10+7/lib/openjdk"
      exec uvx --from serena-agent \
        serena start-mcp-server \
        --context ide-assistant \
        --project-from-cwd "$@"
    '';
  };
in {
  # Registered via the `local.extraMcpServers` side-channel (same pattern as
  # oracle-sqlcl-mcp.nix / kindly-web-search.nix). `optional = true` keeps it
  # out of the global mcpServers wiring; opt in per-project via
  #   claude-kit.nix:mcp = [ "serena" ];
  # then `claude-kit project sync` mirrors it into ./.mcp.json.
  #
  # Per-project prerequisite (not nix-managed): a `.serena/project.yml` with
  #   languages: [ java ]
  #   ls_specific_settings:
  #     java:
  #       jdtls_path:  ~/.local/share/nvim/mason/packages/jdtls
  #       lombok_path: ~/.local/share/nvim/mason/packages/jdtls/lombok.jar
  #       java_home:   <openjdk-21 …/lib/openjdk>
  local.extraMcpServers.serena = {
    command = lib.getExe serenaWrapper;
    optional = true;
  };
}
