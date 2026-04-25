# Claude Code — declarative skills + MCP server configuration (Home Manager).
#
# ── Skills ────────────────────────────────────────────────────────────────
# `skillRoots` below is a list of directories. Every subdirectory inside each
# root becomes a skill under ~/.claude/skills/<name>/. No manual copying, no
# SHA256 hashes.
#
# To add skills from another GitHub repo:
#   1. In flake.nix, add a new input with `flake = false`:
#        inputs.my-skills = { url = "github:owner/repo"; flake = false; };
#   2. Append to `skillRoots` below the path inside that repo that contains
#      the skill subdirectories, e.g. `"${inputs.my-skills}"` or
#      `"${inputs.my-skills}/skills"`.
#   3. `nix flake update my-skills` to bump; the lockfile pins the revision,
#      so there is no hash to maintain.
#
# If you want a one-off fetch without touching flake.nix, you can use
#   (builtins.fetchGit { url = "https://github.com/owner/repo"; ref = "main"; shallow = true; }).outPath
# as a root entry. This is impure (requires `--impure` or just works inside HM
# activation), but also avoids hashes.
#
# ── MCP servers ──────────────────────────────────────────────────────────
# Servers come from the canonical registry at modules/common/mcp-servers.nix.
# Binaries are provided by natsukium/mcp-servers-nix (no hashes to manage).
# Custom non-catalog servers (like code-index) live alongside in ./code-index.nix.
{
  inputs,
  lib,
  pkgs,
  ...
}: let
  registry = inputs.self.commonModules.mcpServers;
  mcp = inputs.mcp-servers-nix.packages.${pkgs.stdenv.hostPlatform.system};

  # List each root directory that contains skill subdirectories.
  # Every subdir of every root gets auto-imported — good for skill-only repos
  # like anthropics/skills. Add more flake-input repos or local paths here.
  skillRoots = [
    "${inputs.anthropics-skills}/skills"
    ./skills
  ];

  # Cherry-pick individual skills from larger repos where you don't want the
  # whole tree. Key = skill name (becomes ~/.claude/skills/<key>/), value = path.
  extraSkills = {
    er-diagram-and-data-modeling = "${inputs.vibekit}/plugins/architecture-tools/skills/er-diagram-and-data-modeling";
  };

  # Enumerate every direct subdirectory of a root and turn it into a
  # (name → path) pair suitable for programs.claude-code.skills.
  collectSkills = root:
    lib.mapAttrs'
    (name: _: lib.nameValuePair name "${toString root}/${name}")
    (lib.filterAttrs (_: t: t == "directory") (builtins.readDir root));

  allSkills = (lib.foldl' (acc: root: acc // collectSkills root) {} skillRoots) // extraSkills;

  # Wrapper for git-sourced MCP servers. The fetched source lives in the Nix
  # store (read-only), but uv/pipx/npm need a writable project dir to create
  # .venv / node_modules / etc. On first run we copy the repo into
  # $XDG_CACHE_HOME/mcp-servers/<name>-<rev>/ and run the launcher from there.
  # The rev is part of the path, so bumping gitSource.rev triggers a fresh copy.
  #
  # To add a new runtime (pipx-run, npm-run, …), extend the `launcher` branch.
  mkGitServer = {
    name,
    gitSource,
    runtime,
    entrypoint,
    patches ? [],
  }: let
    rawSrc = pkgs.fetchFromGitHub gitSource;
    src =
      if patches == []
      then rawSrc
      else
        pkgs.applyPatches {
          name = "${gitSource.repo}-${gitSource.rev}-patched";
          src = rawSrc;
          inherit patches;
        };
    # Key the writable workdir on the store-path hash of `src`, so patch
    # edits (not just rev bumps) invalidate stale copies.
    srcKey = builtins.substring 0 12 (baseNameOf "${src}");
    launcher =
      if runtime == "uv-run"
      then ''exec ${lib.getExe pkgs.uv} run python ${lib.escapeShellArg entrypoint} "$@"''
      else throw "claude.nix: unsupported git-source runtime '${runtime}' for MCP server '${name}'";
    runtimeInputs =
      if runtime == "uv-run"
      then [pkgs.uv]
      else [];
  in
    pkgs.writeShellApplication {
      name = "mcp-${name}";
      inherit runtimeInputs;
      text = ''
        workdir="''${XDG_CACHE_HOME:-$HOME/.cache}/mcp-servers/${name}-${srcKey}"
        if [ ! -e "$workdir/.ready" ]; then
          mkdir -p "$workdir"
          cp -rL --no-preserve=mode,ownership "${src}/." "$workdir/"
          touch "$workdir/.ready"
        fi
        cd "$workdir"
        ${launcher}
      '';
    };

  # Wrapper for `npxDirect` MCP servers — lazy `npx --yes <pkg>` invocation,
  # mirroring the ruflo-cli.nix pattern. No Nix-level version pinning; npm
  # resolves on first call and caches under $XDG_CACHE_HOME. Used for
  # Node-based MCP servers that aren't in natsukium's catalog yet.
  mkNpxDirectServer = name: package:
    pkgs.writeShellApplication {
      name = "mcp-${name}";
      runtimeInputs = [pkgs.nodejs_20];
      text = ''
        export NPM_CONFIG_CACHE="''${XDG_CACHE_HOME:-$HOME/.cache}/mcp-npx/npm-cache"
        export NPM_CONFIG_PREFIX="''${XDG_CACHE_HOME:-$HOME/.cache}/mcp-npx/npm-prefix"
        mkdir -p "$NPM_CONFIG_CACHE" "$NPM_CONFIG_PREFIX/lib" "$NPM_CONFIG_PREFIX/bin"
        exec npx --yes ${lib.escapeShellArg package} "$@"
      '';
    };

  # Per-server environment overrides for registry entries whose env values
  # depend on Nix-store paths (e.g. a chromium binary for puppeteer). These
  # can't live in modules/common/mcp-servers.nix because that file is a plain
  # attrset with no `pkgs` in scope.
  mcpEnvOverrides = {
    mermaid = {
      PUPPETEER_EXECUTABLE_PATH = "${pkgs.chromium}/bin/chromium";
      PUPPETEER_SKIP_CHROMIUM_DOWNLOAD = "true";
    };
  };

  # Map each registry entry to a Claude Code mcpServers spec. Catalog entries
  # resolve to the natsukium binary; git-sourced entries resolve to a wrapper
  # script (see mkGitServer); npxDirect entries resolve to a lazy npx shim
  # (see mkNpxDirectServer). `env`/`args` passthrough when set, merged with
  # any Nix-path-dependent overrides from mcpEnvOverrides.
  mkClaudeServer = name: def: let
    mergedEnv = (def.env or {}) // (mcpEnvOverrides.${name} or {});
  in
    (
      if def ? gitSource
      then {
        command = lib.getExe (mkGitServer ({
            inherit name;
            inherit (def) gitSource runtime entrypoint;
          }
          // lib.optionalAttrs (def ? patches) {inherit (def) patches;}));
      }
      else if def ? npxDirect
      then {
        command = lib.getExe (mkNpxDirectServer name def.npxDirect.package);
      }
      else {
        command = lib.getExe mcp.${def.mcpServerNix};
      }
    )
    // lib.optionalAttrs (def ? args && !(def ? gitSource) && !(def ? npxDirect)) {inherit (def) args;}
    // lib.optionalAttrs (mergedEnv != {}) {env = mergedEnv;};
in {
  programs.claude-code = {
    enable = true;

    # Local skills override upstream on name clash (later foldl' entries win).
    skills = allSkills;

    mcpServers = lib.mapAttrs mkClaudeServer registry;

    # ~/.claude/settings.json contents. `bypassPermissions` is the default
    # mode so new project folders (including ccmanager bindfs mounts) are
    # trusted without a prompt — flip via `/permissions` per-session when
    # you want stricter behavior. `skip*PermissionPrompt` suppress the
    # first-run opt-in dialogs for auto and bypass modes.
    settings = {
      effortLevel = "high";
      skipAutoPermissionPrompt = true;
      skipDangerousModePermissionPrompt = true;
      permissions.defaultMode = "bypassPermissions";
      enabledPlugins."frontend-design@claude-plugins-official" = true;
    };
  };
}
