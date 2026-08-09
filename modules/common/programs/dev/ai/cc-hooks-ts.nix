# cc-hooks-ts — type-safe TypeScript hook handlers for Claude Code.
#
# https://github.com/sushichan044/cc-hooks-ts — a maintained npm library
# (`defineHook`/`runHook`, full payload typing) rather than a scaffold-and-fork.
# Replaced johnlindquist/claude-hooks (the old `claude-hooks.nix`), whose
# example behaviours were dropped; the handlers we actually want are the
# hand-written files under Notes/claude/hooks/ (guard, fmt, notify — plus any
# you drop in later).
#
# Dynamic dispatch:
#   Individual hook files are NOT registered in settings.json. Instead a single
#   dispatcher (_dispatch.ts) is registered once per event; at runtime it fans
#   the payload out to every sibling *.ts whose defineHook `trigger` declares
#   the fired event. So dropping a new hook file into Notes/claude/hooks/ is
#   picked up on the next `claude` session with NO nix_switch. Only adding a
#   brand-new *event* to route (rare) means editing `dynamicEvents` below.
#
# Wiring:
#   • Hook TS lives under Notes/claude/hooks/, surfaced into ~/.claude/hooks/
#     via mkOutOfStoreSymlink (same live-edit pattern as skills/ and commands/).
#     Editing OR adding a *.ts applies on the next `claude` session.
#   • cc-hooks-ts is a *runtime import*, not a CLI. It's pinned in
#     Notes/claude/hooks/package.json and lazy-installed by the `cc-hooks-run`
#     wrapper into $XDG_CACHE_HOME on first fire (ruflo-cli / claude-powerline
#     idiom — no nix hash to maintain). The wrapper then symlinks node_modules
#     into the hooks dir so bun resolves the import from each file's real path.
#   • The dispatcher registers through the shared `local.extraHooks` side-channel
#     in claude.nix — concats (not clobbers) with rtk's PreToolUse(Bash) entry
#     and the caveman Stop hook. `listOf` element type makes same-event
#     contributions from different files merge.
#   • bun stays on home.packages (hook spawn runtime). alejandra (fmt.ts) and
#     libnotify/notify-send (notify.ts, Linux only) are added here so the hook
#     subprocesses find them on PATH.
{
  pkgs,
  lib,
  config,
  ...
}: let
  # Keep in sync with Notes/claude/hooks/package.json.
  version = "2.1.203";

  hooksSrc = "${config.home.homeDirectory}/killuanix/Notes/claude/hooks";

  # Lazy-install cc-hooks-ts into an XDG-cache dir keyed by version, expose it
  # to the live hooks dir via a node_modules symlink, then exec the hook file.
  # Idempotent + cheap on the hot path (two `[ -e ]` checks after first run).
  runner = pkgs.writeShellApplication {
    name = "cc-hooks-run";
    runtimeInputs = [pkgs.bun pkgs.coreutils];
    text = ''
      cache="''${XDG_CACHE_HOME:-$HOME/.cache}/cc-hooks-ts/v${version}"
      hooks=${lib.escapeShellArg hooksSrc}

      if [ ! -e "$cache/node_modules/cc-hooks-ts/package.json" ]; then
        mkdir -p "$cache"
        printf '{"dependencies":{"cc-hooks-ts":"%s"}}\n' ${lib.escapeShellArg version} > "$cache/package.json"
        bun install --cwd "$cache" >/dev/null 2>&1 || true
      fi

      # bun resolves node_modules by walking up from the hook file's REAL path
      # (Notes/claude/hooks), so point a symlink there at the cache install.
      if [ -d "$cache/node_modules" ] && [ ! -e "$hooks/node_modules" ]; then
        ln -sfn "$cache/node_modules" "$hooks/node_modules" 2>/dev/null || true
      fi

      exec bun run --silent "$1"
    '';
  };

  # Single dynamic dispatcher. Registered once per event below; at runtime it
  # fans the payload out to every sibling *.ts whose defineHook `trigger`
  # declares the fired event (see _dispatch.ts). Dropping a new hook file into
  # Notes/claude/hooks/ is therefore picked up on the next `claude` session with
  # NO settings.json change and NO nix_switch — only adding a brand-new *event*
  # to route (rare) means editing `dynamicEvents` here.
  dispatchCmd = {
    type = "command";
    command = "${lib.getExe runner} ${config.home.homeDirectory}/.claude/hooks/_dispatch.ts";
    timeout = 60; # generous cap; dispatch may spawn several child hooks (e.g. alejandra)
  };

  # The Claude Code hook events the dispatcher is wired for. Matcher-less: the
  # dispatcher fires for every tool and each hook does its own tool-level
  # filtering via its `trigger`.
  dynamicEvents = [
    "PreToolUse"
    "PostToolUse"
    "UserPromptSubmit"
    "Notification"
    "Stop"
    "SubagentStop"
    "PreCompact"
    "SessionStart"
    "SessionEnd"
  ];
in {
  home.packages =
    [pkgs.bun pkgs.alejandra]
    ++ lib.optionals pkgs.stdenv.isLinux [pkgs.libnotify];

  # Live-editable TS handlers. Whole dir symlinked so new files show up without
  # re-evaluating the module.
  home.file.".claude/hooks".source =
    config.lib.file.mkOutOfStoreSymlink hooksSrc;

  # One dispatcher entry per event. Concats (not clobbers) with rtk's
  # PreToolUse(Bash) entry and the caveman Stop hook via the shared side-channel.
  local.extraHooks = lib.genAttrs dynamicEvents (_: [{hooks = [dispatchCmd];}]);
}
