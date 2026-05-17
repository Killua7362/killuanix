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

  # Cherry-pick individual skills from larger flake-input repos where you
  # don't want the whole tree. Key = skill name (becomes ~/.claude/skills/<key>/),
  # value = nix-store path. These are nix-managed (read-only) and require
  # `scripts/nix_switch` to update.
  #
  # Upstream bundles (anthropics/skills, ruflo, wshobson) live in the lazy
  # catalog (Notes/claude/lazy/upstream/) — opt in per-project via
  # `claude-kit lazy add skill <name>`.
  #
  # Local hand-authored always-on skills live in Notes/claude/skills/ and are
  # wired as out-of-store symlinks under `config.home.file` below (same
  # live-edit pattern as Notes/claude/{global.md,memory,commands}).
  extraSkills = {};

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
        # Caveman state files that must not be symlinked into the overlay.
        # Each session's `.caveman-statusline-suffix` is *per-session* (the
        # statusline badge tracks the current claude run, not lifetime), so
        # both files must live inside the overlay where they're isolated
        # from other concurrent sessions. Symlinking either one through to
        # `~/.claude/` would (a) let every session's Stop hook follow the
        # symlink and write through to one shared real file (badges
        # converge), and (b) trigger upstream symlink-refusal guards.
        #   - `.caveman-active` — caveman's SessionStart hook
        #     (caveman-activate.js) writes it via `safeWriteFlag`, which
        #     silently aborts on existing symlinks (caveman-config.js:
        #     122-141 — defence against an attacker pointing the flag at
        #     ~/.ssh/id_rsa). Symlinking it would block activation and
        #     leave the statusline with no `[CAVEMAN]` badge at all.
        #   - `.caveman-statusline-suffix` — caveman-statusline.sh refuses
        #     to render the badge if this file is a symlink (same
        #     anti-ANSI-injection defence).
        # Neither file is pre-copied — caveman-activate.js creates the
        # active flag fresh on SessionStart, and the Stop hook fills the
        # suffix after the first assistant turn. Suffix is empty in
        # between, which renders nothing (caveman-statusline.sh only
        # emits the `⛏ N` tail when the file is non-empty).
        caveman_skip_symlink=(.caveman-active .caveman-statusline-suffix)
        if [ -d "$src" ]; then
          while IFS= read -r -d "" entry; do
            base="$(basename "$entry")"
            [ "$base" = settings.json ] && continue
            _skip=0
            for _cf in "''${caveman_skip_symlink[@]}"; do
              [ "$base" = "$_cf" ] && _skip=1 && break
            done
            [ "$_skip" -eq 1 ] && continue
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
  # swapped. Inherits version/meta so `claude --version`, claude-powerline, and
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
  # Side-channel for MCP server stanzas defined outside mcp-servers.nix
  # (servers that need `pkgs` / sops in scope, e.g. code-index, jupyter-env,
  # jupyter). Each entry may include `optional = true` — same semantics as
  # the registry: excluded from global wiring, still resolvable through
  # `claude-kit project sync` via the all-mcp-servers.json catalog below.
  options.local.extraMcpServers = lib.mkOption {
    type = lib.types.attrsOf (lib.types.attrsOf lib.types.unspecified);
    default = {};
    description = "Pre-resolved MCP server stanzas defined outside mcp-servers.nix.";
  };

  config = {
    programs.claude-code = {
      enable = true;
      package = claudeWithOverlay;

      # Cherry-picked skills from flake-input repos. Local always-on skills
      # are wired separately via home.file mkOutOfStoreSymlink (see below) so
      # they live-edit out of Notes/claude/skills/.
      skills = extraSkills;

      # Optional entries (`optional = true` in mcp-servers.nix) are excluded
      # from the global wiring — they're per-project tools that should only
      # load when a project's claude-kit.nix opts in via `mcp = [ "name" ]`.
      # The full resolved registry (including optionals) is emitted to
      # $XDG_DATA_HOME/claude-kit/all-mcp-servers.json below so
      # `claude-kit project sync` can still mirror their stanzas into a
      # project's ./.mcp.json on demand.
      mcpServers =
        (lib.mapAttrs mkClaudeServer
          (lib.filterAttrs (_: v: !(v.optional or false)) registry))
        // (lib.mapAttrs (_: v: builtins.removeAttrs v ["optional"])
          (lib.filterAttrs (_: v: !(v.optional or false)) config.local.extraMcpServers));

      # ~/.claude/settings.json contents. `bypassPermissions` is the default
      # mode so new project folders (including ccmanager bindfs mounts) are
      # trusted without a prompt — flip via `/permissions` per-session when
      # you want stricter behavior. `skip*PermissionPrompt` suppress the
      # first-run opt-in dialogs for auto and bypass modes.
      settings = {
        model = "claude-opus-4-7";
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

        # Status line — declarative config lives in `claude-powerline.nix` and
        # is rendered to ~/.config/claude-powerline/config.json. The shim lazy-
        # compiles upstream into a Bun-native single binary on first run and
        # exec's it on every refresh after that (no per-render Node boot).
        # PATH lookup works for plain `claude` and for `claude-launchers.nix`
        # wrappers. `refreshInterval` honoured on Claude Code >= 2.1.97.
        statusLine = {
          type = "command";
          command = "claude-powerline";
          padding = 0;
          refreshInterval = 10;
        };

        # Auto-refresh caveman lifetime savings suffix after every assistant
        # turn. caveman-stats.js parses the live session jsonl, appends a
        # snapshot to ~/.claude/.caveman-history.jsonl, and rewrites
        # ~/.claude/.caveman-statusline-suffix — the pre-rendered string the
        # statusline reads (see caveman-statusline.sh). Without this hook the
        # suffix only updates when /caveman-stats is invoked by hand, so a
        # fresh shell never shows the badge until the user types the command.
        # `node` resolves from PATH (provided by nodejs_20 in
        # ruflo-cli.nix/claude-flow-cli.nix). Output silenced; only side-effect
        # we want is the suffix file write.
        hooks.Stop = [
          {
            hooks = [
              {
                type = "command";
                # Per-session caveman savings badge.
                #
                # Reads the hook stdin payload (Claude Code passes
                # `{transcript_path, session_id, …}` to Stop hooks), parses
                # *only that session's jsonl* to sum output tokens, looks
                # up the live mode from the overlay's .caveman-active, and
                # writes a per-overlay
                # `$CLAUDE_CONFIG_DIR/.caveman-statusline-suffix` of the
                # form `⛏ Nk`. Intentionally bypasses the upstream
                # `caveman-stats.js`, which aggregates lifetime totals
                # across every session's history snapshot and would render
                # the same number in every concurrent session's badge.
                #
                # Lifetime / 5h block aggregation lives separately in the
                # `caveman stats` shell wrapper (scripts/caveman) which
                # reads jsonls directly from ~/.claude/projects/.
                #
                # Savings ratio comes from caveman's `full`-mode benchmark
                # (~65% mean per-task token reduction; the only mode with
                # benchmark data). Other modes render an empty suffix.
                command = ''
                  node -e '
                  const fs = require("fs");
                  const path = require("path");
                  const os = require("os");
                  const COMPRESSION = { full: 0.65 };

                  let input = "";
                  process.stdin.on("data", d => input += d);
                  process.stdin.on("end", () => {
                    let payload = {};
                    try { payload = JSON.parse(input); } catch {}
                    const transcript = payload.transcript_path;
                    const claudeDir = process.env.CLAUDE_CONFIG_DIR || path.join(os.homedir(), ".claude");
                    const suffixPath = path.join(claudeDir, ".caveman-statusline-suffix");

                    let mode = null;
                    try {
                      mode = fs.readFileSync(path.join(claudeDir, ".caveman-active"), "utf8")
                        .trim().toLowerCase().replace(/[^a-z0-9-]/g, "");
                    } catch {}
                    const ratio = COMPRESSION[mode];

                    function safeWrite(s) {
                      try {
                        try { if (fs.lstatSync(suffixPath).isSymbolicLink()) return; } catch (e) { if (e.code !== "ENOENT") return; }
                        fs.writeFileSync(suffixPath, s, { mode: 0o600 });
                      } catch {}
                    }

                    if (!ratio || !transcript || !fs.existsSync(transcript)) {
                      safeWrite("");
                      return;
                    }

                    let outTokens = 0;
                    try {
                      for (const line of fs.readFileSync(transcript, "utf8").split("\n")) {
                        if (!line.trim()) continue;
                        try {
                          const e = JSON.parse(line);
                          if (e.type !== "assistant" || !e.message || !e.message.usage) continue;
                          outTokens += e.message.usage.output_tokens || 0;
                        } catch {}
                      }
                    } catch {}

                    const saved = Math.round(outTokens / (1 - ratio)) - outTokens;
                    const humanize = n => n >= 1e6 ? (n / 1e6).toFixed(1) + "M"
                                      : n >= 1e3 ? (n / 1e3).toFixed(1) + "k"
                                      : String(n);
                    safeWrite(saved > 0 ? "⛏ " + humanize(saved) : "");
                  });
                  ' 2>/dev/null || true
                '';
                timeout = 5;
              }
            ];
          }
        ];

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

    # Full MCP registry catalog (including `optional = true` entries excluded
    # from the global wiring above). Read by `claude-kit project sync` to
    # resolve server stanzas requested via a project's claude-kit.nix `mcp`
    # list. Read-only nix-store symlink; never hand-edit.
    xdg.dataFile."claude-kit/all-mcp-servers.json".source =
      pkgs.writeText "all-mcp-servers.json"
      (builtins.toJSON
        ((lib.mapAttrs mkClaudeServer registry)
          // (lib.mapAttrs (_: v: builtins.removeAttrs v ["optional"])
            config.local.extraMcpServers)));

    # Memory centralisation — Notes/claude/ is the single source of truth.
    #
    # Global instructions, per-project auto-memory, always-on local skills,
    # and user-defined slash commands all live as committed markdown in the
    # Notes submodule. mkOutOfStoreSymlink points at the live path (not the
    # Nix store), so content edits flow bidirectionally and Claude's
    # auto-memory writes land in the vault for the user to commit via
    # Obsidian's `Obsidian Git: Create backup` command (auto-intervals are
    # intentionally 0).
    #
    # Skills and commands are auto-discovered via builtins.readDir on the
    # vault path: each subdir of Notes/claude/skills/ becomes
    # ~/.claude/skills/<name>, each .md file under Notes/claude/commands/
    # becomes ~/.claude/commands/<file>.md. Adding a new dir/file requires
    # `scripts/nix_switch` (re-evaluates readDir); content edits inside
    # existing entries don't. Commands sit alongside the flattened
    # ruflo--*/wshobson--* bundle (claude-resources.nix uses `recursive =
    # true` so per-file additions don't conflict).
    home.file = let
      # Absolute path constructed from a string so Nix doesn't try to
      # treat it as part of the flake source tree (which would require
      # every entry inside the Notes submodule to be tracked at the
      # parent repo level — impossible by definition). Requires
      # `nix --impure` at build time; scripts/nix_switch passes it.
      liveBase = "${config.home.homeDirectory}/killuanix/Notes/claude";
      notesSkills = /. + "${liveBase}/skills";
      notesCommands = /. + "${liveBase}/commands";

      mkSkill = name: _:
        lib.nameValuePair ".claude/skills/${name}" {
          source = config.lib.file.mkOutOfStoreSymlink "${liveBase}/skills/${name}";
        };
      mkCommand = name: _:
        lib.nameValuePair ".claude/commands/${name}" {
          source = config.lib.file.mkOutOfStoreSymlink "${liveBase}/commands/${name}";
        };

      skillDirs =
        lib.filterAttrs (_: t: t == "directory")
        (builtins.readDir notesSkills);
      commandFiles =
        lib.filterAttrs (n: t: t == "regular" && lib.hasSuffix ".md" n)
        (builtins.readDir notesCommands);
    in
      {
        ".claude/CLAUDE.md".source =
          config.lib.file.mkOutOfStoreSymlink "${liveBase}/global.md";
        ".claude/projects/-home-killua-killuanix/memory".source =
          config.lib.file.mkOutOfStoreSymlink "${liveBase}/memory";
      }
      // (lib.mapAttrs' mkSkill skillDirs)
      // (lib.mapAttrs' mkCommand commandFiles);

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
  }; # config
}
