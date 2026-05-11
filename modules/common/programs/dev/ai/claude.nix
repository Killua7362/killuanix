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
  config,
  lib,
  pkgs,
  ...
}: let
  registry = inputs.self.commonModules.mcpServers;
  mcp = inputs.mcp-servers-nix.packages.${pkgs.stdenv.hostPlatform.system};

  # List each root directory that contains skill subdirectories.
  # Every subdir of every root gets auto-imported into ~/.claude/skills/ —
  # i.e. always-on, billed in every session's startup blob.
  #
  # Upstream bundles (anthropics/skills, ruflo, wshobson) used to live here
  # but are now in the lazy catalog (Notes/claude/lazy/upstream/) — opt in
  # per-project via `claude-kit lazy add skill <name>`.
  #
  # Keep this list to local skills you genuinely want loaded everywhere.
  skillRoots = [
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
    runtimeInputs =
      if runtime == "uv-run"
      then [pkgs.uv]
      else throw "claude.nix: unsupported git-source runtime '${runtime}' for MCP server '${name}'";
  in
    pkgs.writeShellApplication {
      name = "mcp-${name}";
      inherit runtimeInputs;
      text = ''
        export MCP_NAME=${lib.escapeShellArg name}
        export MCP_SRCKEY=${lib.escapeShellArg srcKey}
        export MCP_SRC=${src}
        export MCP_RUNTIME=${lib.escapeShellArg runtime}
        export MCP_ENTRYPOINT=${lib.escapeShellArg entrypoint}
        exec bash ${./claude/scripts/mcp-git-server.sh} "$@"
      '';
    };

  # Wrapper for `npxDirect` MCP servers — lazy `npx --yes <pkg>` invocation,
  # mirroring the ruflo-cli.nix pattern. No Nix-level version pinning; npm
  # resolves on first call and caches under $XDG_CACHE_HOME. Used for
  # Node-based MCP servers that aren't in natsukium's catalog yet.
  #
  # `cacheNamespace` chooses the $XDG_CACHE_HOME/<ns>/ subdir for npm cache
  # and prefix. Default is "mcp-npx" (isolated from other tools). Set this
  # to "ruflo" on a server that runs the same npm package as ruflo-cli.nix
  # so the on-disk install is shared — otherwise Claude Code's MCP connect
  # probe times out on cold start while npx downloads the dep tree.
  mkNpxDirectServer = {
    name,
    package,
    cacheNamespace ? "mcp-npx",
  }:
    pkgs.writeShellApplication {
      name = "mcp-${name}";
      runtimeInputs = [pkgs.nodejs_20];
      text = ''
        export NPM_CONFIG_CACHE="''${XDG_CACHE_HOME:-$HOME/.cache}/${cacheNamespace}/npm-cache"
        export NPM_CONFIG_PREFIX="''${XDG_CACHE_HOME:-$HOME/.cache}/${cacheNamespace}/npm-prefix"
        mkdir -p "$NPM_CONFIG_CACHE" "$NPM_CONFIG_PREFIX/lib" "$NPM_CONFIG_PREFIX/bin"
        exec npx --yes ${lib.escapeShellArg package} "$@"
      '';
    };

  # Wrapper for `uvxDirect` MCP servers — lazy `uvx <pkg>` invocation for
  # Python MCP servers published to PyPI but not yet in natsukium's catalog.
  # Mirrors `mkNpxDirectServer` but uses uv's tool runner. uv caches resolved
  # envs under $UV_CACHE_DIR, so first call is slow and subsequent calls hit
  # cache. `cacheNamespace` lets multiple servers share an env prefix where
  # useful (default "mcp-uvx" — isolated).
  mkUvxDirectServer = {
    name,
    package,
    cacheNamespace ? "mcp-uvx",
  }:
    pkgs.writeShellApplication {
      name = "mcp-${name}";
      runtimeInputs = [pkgs.uv];
      text = ''
        export UV_CACHE_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/${cacheNamespace}/uv-cache"
        mkdir -p "$UV_CACHE_DIR"
        exec uvx ${lib.escapeShellArg package} "$@"
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
  # (see mkNpxDirectServer); uvxDirect entries resolve to a lazy uvx shim
  # (see mkUvxDirectServer). `env`/`args` passthrough when set, merged with
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
        command = lib.getExe (mkNpxDirectServer {
          inherit name;
          inherit (def.npxDirect) package;
          cacheNamespace = def.npxDirect.cacheNamespace or "mcp-npx";
        });
      }
      else if def ? uvxDirect
      then {
        command = lib.getExe (mkUvxDirectServer {
          inherit name;
          inherit (def.uvxDirect) package;
          cacheNamespace = def.uvxDirect.cacheNamespace or "mcp-uvx";
        });
      }
      else {
        command = lib.getExe mcp.${def.mcpServerNix};
      }
    )
    // lib.optionalAttrs (def ? args && !(def ? gitSource)) {inherit (def) args;}
    // lib.optionalAttrs (mergedEnv != {}) {env = mergedEnv;};

  # ── /effort overlay wrapper ───────────────────────────────────────────────
  # `~/.claude/settings.json` is a HM-symlink into the read-only nix store, so
  # Claude Code's `/effort medium|auto|low|xhigh` commands (which open the file
  # O_RDWR to mutate-in-place) hit EACCES before they touch JSON. `/effort max`
  # works only because Claude treats max as a transient session boost (no
  # write); `/model` works because it writes to ~/.claude.json (a separate
  # file Claude owns, mode 0600).
  #
  # Boot every `claude` process through this wrapper: per-PID overlay dir
  # under $XDG_RUNTIME_DIR mirrors ~/.claude/ as symlinks for everything
  # except settings.json, which gets a fresh writable copy from the
  # nix-managed source. CLAUDE_CONFIG_DIR points Claude at the overlay, so
  # `/effort medium` mutates the overlay copy — declarative source untouched,
  # changes evaporate at next launch.
  #
  # If a caller (e.g. claude-launchers.nix' claude-algo) already prepared a
  # CLAUDE_CONFIG_DIR, we don't replace it — we just rewrite that dir's
  # settings.json from symlink-into-store into a writable copy. One conditional
  # covers both code paths so the launchers don't need parallel logic.
  overlayClaude = pkgs.writeShellApplication {
    name = "claude";
    runtimeInputs = [pkgs.coreutils pkgs.findutils];
    text = ''
      src="$HOME/.claude"

      if [ -n "''${CLAUDE_CONFIG_DIR:-}" ] && [ -d "$CLAUDE_CONFIG_DIR" ]; then
        if [ -e "$CLAUDE_CONFIG_DIR/settings.json" ] \
           && { [ -L "$CLAUDE_CONFIG_DIR/settings.json" ] || [ ! -w "$CLAUDE_CONFIG_DIR/settings.json" ]; }; then
          _real=$(readlink -f "$CLAUDE_CONFIG_DIR/settings.json")
          rm -f "$CLAUDE_CONFIG_DIR/settings.json"
          install -m 0644 "$_real" "$CLAUDE_CONFIG_DIR/settings.json"
        fi
      else
        state_dir="$(mktemp -d "''${XDG_RUNTIME_DIR:-/tmp}/claude-session.XXXXXX")"
        trap 'rm -rf "$state_dir"' EXIT INT TERM HUP
        if [ -d "$src" ]; then
          while IFS= read -r -d "" entry; do
            base="$(basename "$entry")"
            [ "$base" = settings.json ] && continue
            ln -sfn "$entry" "$state_dir/$base"
          done < <(find "$src" -mindepth 1 -maxdepth 1 -print0)
        fi
        if [ -e "$src/settings.json" ]; then
          install -m 0644 "$src/settings.json" "$state_dir/settings.json"
        fi
        # Auth + onboarding state lives at $HOME/.claude.json (sibling of
        # ~/.claude/, NOT inside it). With CLAUDE_CONFIG_DIR set, Claude reads
        # this file from that dir — symlink it through so writes (token
        # refresh, onboarding flags) persist back to the real file instead of
        # evaporating with the per-PID state_dir.
        if [ -e "$HOME/.claude.json" ]; then
          ln -sfn "$HOME/.claude.json" "$state_dir/.claude.json"
        fi
        export CLAUDE_CONFIG_DIR="$state_dir"
      fi

      ${pkgs.claude-code}/bin/claude "$@"
    '';
  };

  # Wrap upstream claude-code so its bin/claude resolves to overlayClaude.
  # `cp -as` mirrors the upstream tree as symlinks so future additions to the
  # package (man pages, completions, …) flow through; only bin/claude is
  # swapped. Inherits version/meta so `claude --version`, ccstatusline, and
  # any other consumer reading cfg.finalPackage.{version,meta} stay accurate.
  claudeWithOverlay =
    pkgs.runCommand "claude-code-${pkgs.claude-code.version}-overlay" {
      inherit (pkgs.claude-code) version meta;
    } ''
      mkdir -p $out
      cp -as ${pkgs.claude-code}/. $out/
      chmod -R +w $out/bin
      rm -f $out/bin/claude
      ln -s ${overlayClaude}/bin/claude $out/bin/claude
    '';
in {
  programs.claude-code = {
    enable = true;
    package = claudeWithOverlay;

    # Local skills override upstream on name clash (later foldl' entries win).
    skills = allSkills;

    mcpServers = lib.mapAttrs mkClaudeServer registry;

    # ~/.claude/settings.json contents. `bypassPermissions` is the default
    # mode so new project folders (including ccmanager bindfs mounts) are
    # trusted without a prompt — flip via `/permissions` per-session when
    # you want stricter behavior. `skip*PermissionPrompt` suppress the
    # first-run opt-in dialogs for auto and bypass modes.
    settings = {
      model = "claude-sonnet-4-6";
      effortLevel = "high";
      skipAutoPermissionPrompt = true;
      skipDangerousModePermissionPrompt = true;
      permissions.defaultMode = "bypassPermissions";

      # Pin to the nix-managed binary. Claude Code's built-in updater
      # drops a fresh `claude` into ~/.local/bin/ on each launch, which
      # shadows ~/.nix-profile/bin/claude on PATH and bypasses the
      # `--plugin-dir` wrapper that loads our .mcp.json bundle (so MCP
      # servers silently disappear). Disabling auto-updates keeps the
      # flake-pinned `pkgs.claude-code` authoritative; bump it via
      # `nix flake update` instead.
      autoUpdates = false;

      # Use the flicker-free alt-screen renderer so the live conversation
      # doesn't get mirrored into the terminal's normal scrollback. Use
      # `Ctrl+O` then `[` inside Claude Code to dump the transcript into
      # scrollback on demand.
      tui = "fullscreen";

      # Status line — declarative config lives in `ccstatusline.nix` and is
      # rendered to ~/.config/ccstatusline/settings.json. PATH lookup of the
      # `ccstatusline` shim works for plain `claude` and for launchers under
      # `claude-launchers.nix` (which inherit the user's PATH).
      # `refreshInterval` is honoured on Claude Code >= 2.1.97.
      statusLine = {
        type = "command";
        command = "ccstatusline";
        padding = 0;
        refreshInterval = 10;
      };

      # Declaratively register the ruflo marketplace. Equivalent to running
      # `/plugin marketplace add ruvnet/ruflo` once, but reproducible across
      # machines. Claude Code resolves the source on first launch into
      # ~/.claude/plugins/marketplaces/ruflo/.
      extraKnownMarketplaces.ruflo.source = {
        source = "github";
        repo = "ruvnet/ruflo";
      };

      # JuliusBrussee/caveman — communication-style plugin that compresses
      # assistant output ~75% via "caveman-speak". Bundles companion skills
      # (caveman, compress, cavecrew, caveman-{commit,review,help,stats})
      # and Node-based SessionStart/UserPromptSubmit hooks that auto-activate
      # the mode. The upstream `caveman-shrink` MCP proxy is intentionally
      # not registered — it's a stdio wrapper for compressing *another* MCP
      # server's output, not a standalone server, and bare registration
      # (the way upstream's install.sh does it) fails with "missing upstream
      # command" on every session start.
      extraKnownMarketplaces.caveman.source = {
        source = "github";
        repo = "JuliusBrussee/caveman";
      };

      # Plugins are disabled by default — every enabled entry adds its
      # skills/agents/commands to the always-on startup blob. Flip a single
      # plugin to `true` only when you actively need it; re-run
      # `scripts/nix_switch` afterwards. The flat ruflo/wshobson bundles
      # under ~/.claude/{agents,commands,skills}/ are governed separately
      # by `claude-resources.nix` — see the cleanup notes there.
      enabledPlugins = {
        "frontend-design@claude-plugins-official" = false;
        "ruflo-core@ruflo" = false; # MCP server + base agents
        "ruflo-swarm@ruflo" = false; # Swarm coordination + Monitor
        "ruflo-autopilot@ruflo" = false; # Autonomous /loop completion
        "ruflo-loop-workers@ruflo" = false; # Background workers + CronCreate
        "ruflo-security-audit@ruflo" = false; # Security scanning
        "ruflo-rag-memory@ruflo" = false; # HNSW memory + AgentDB
        "ruflo-testgen@ruflo" = false; # Test gap detection + TDD
        "ruflo-docs@ruflo" = false; # Doc generation + drift detection
        "caveman@caveman" = true; # Token-compressed response style + Shrink MCP
      };
    };
  };

  # Memory centralisation — Notes/claude/ is the single source of truth.
  #
  # Both global instructions and per-project auto-memory live as committed
  # markdown in the Notes submodule. mkOutOfStoreSymlink points at the live
  # path (not the Nix store), so edits flow bidirectionally and Claude's
  # auto-memory writes land in the vault for the user to commit via Obsidian's
  # `Obsidian Git: Create backup` command (auto-intervals are intentionally 0).
  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/killuanix/Notes/claude/global.md";

  home.file.".claude/projects/-home-killua-killuanix/memory".source =
    config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/killuanix/Notes/claude/memory";

  # User-defined slash commands sourced from the vault. Live alongside the
  # flattened ruflo--*/wshobson--* command bundle (claude-resources.nix uses
  # `recursive = true` so per-file additions don't conflict). Add new commands
  # by dropping a markdown file into Notes/claude/commands/ and a matching
  # `home.file.".claude/commands/<name>.md".source = mkOutOfStoreSymlink ...`
  # entry below — same pattern as save-chat.
  home.file.".claude/commands/save-chat.md".source =
    config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/killuanix/Notes/claude/commands/save-chat.md";

  # One-shot cleanup: HM activation refuses to replace a real file/dir with
  # a symlink. Pre-2026-04-29:
  #   - ~/.claude/projects/-home-killua-killuanix/memory was a real dir of
  #     auto-memory files (now migrated into Notes/claude/memory/).
  #   - ~/.claude/CLAUDE.md was a 4-line file generated by ruflo init (now
  #     replaced by Notes/claude/global.md).
  # Both stale artefacts are removed before checkLinkTargets runs. Idempotent
  # — only acts when the target is NOT already a symlink.
  home.activation.cleanupOldClaudeMemoryDir = lib.hm.dag.entryBefore ["checkLinkTargets"] ''
    _memdir="$HOME/.claude/projects/-home-killua-killuanix/memory"
    if [ -d "$_memdir" ] && [ ! -L "$_memdir" ]; then
      echo "claude.nix: removing stale auto-memory dir at $_memdir (migrated to Notes/claude/memory/)"
      rm -rf "$_memdir"
    fi

    _claudemd="$HOME/.claude/CLAUDE.md"
    if [ -e "$_claudemd" ] && [ ! -L "$_claudemd" ]; then
      echo "claude.nix: removing stale ~/.claude/CLAUDE.md (replaced by Notes/claude/global.md)"
      rm -f "$_claudemd"
    fi
  '';

  # Patch ruflo plugin settings after Claude Code materializes the marketplace
  # clone. Disables the daemon scheduler so background workers don't linger
  # after sessions end.
  home.activation.patchRufloPluginSettings = lib.hm.dag.entryAfter ["writeBoundary"] ''
    _ruflo_settings="$HOME/.claude/plugins/marketplaces/ruflo/.claude/settings.json"
    if [ -f "$_ruflo_settings" ]; then
      ${lib.getExe pkgs.jq} '
        .claudeFlow.daemon.autoStart = false |
        .claudeFlow.daemon.workers = [] |
        .claudeFlow.daemon.schedules = {}
      ' "$_ruflo_settings" > "$_ruflo_settings.tmp" && mv "$_ruflo_settings.tmp" "$_ruflo_settings"
      echo "claude.nix: patched ruflo daemon settings (autoStart=false, no scheduled workers)"
    fi
  '';
}
