# claude-hooks — TypeScript-powered hook handlers for Claude Code.
#
# https://github.com/johnlindquist/claude-hooks — upstream is a per-project
# scaffolder (`npx claude-hooks` writes ./.claude/hooks/{index,lib,session}.ts
# + merges 7 hook entries into ./.claude/settings.json). We can't run that
# verbatim here: `~/.claude/settings.json` is a read-only nix-store symlink,
# and `~/.claude/hooks/` needs declarative wiring to play nice with the
# per-PID overlay wrapper (see "## /effort overlay wrapper" in claude.nix).
#
# Wiring:
#   • TS files live under Notes/claude/hooks/, surfaced into ~/.claude/hooks/
#     via mkOutOfStoreSymlink (same live-edit pattern as Notes/claude/skills/
#     and Notes/claude/commands/). Edits in Obsidian apply instantly; only
#     adding/removing files needs `scripts/nix_switch`.
#   • Hook commands (`bun ~/.claude/hooks/index.ts <Event>`) are registered
#     through the shared `local.extraHooks` side-channel declared in
#     claude.nix — so we co-exist with claudio (PreToolUse / PostToolUse /
#     UserPromptSubmit) and the caveman Stop hook (also in claude.nix). The
#     side-channel's `listOf` element type means same-event contributions
#     from different files concat instead of clobbering.
#   • bun is added to home.packages — needed at hook spawn time. Already
#     pulled transitively by claude-powerline's build step but not on PATH.
#
# Seeding the TS templates (one-shot, on a fresh checkout):
#   cd /tmp && mkdir claude-hooks-seed && cd claude-hooks-seed
#   npx claude-hooks
#   cp -r .claude/hooks/* ~/killuanix/Notes/claude/hooks/
#   cd ~/killuanix/Notes && git add claude/hooks && git commit
{
  pkgs,
  lib,
  config,
  ...
}: let
  hookCmd = event: "${lib.getExe pkgs.bun} ${config.home.homeDirectory}/.claude/hooks/index.ts ${event}";

  mkEntry = event: [
    {
      matcher = "";
      hooks = [
        {
          type = "command";
          command = hookCmd event;
          timeout = 30;
        }
      ];
    }
  ];

  # The full set of events claude-hooks scaffolds in its default index.ts.
  # Drop any event here if you want to leave it to claudio / caveman /
  # something else (the omitted event simply won't be routed through bun).
  events = [
    "Notification"
    "Stop"
    "PreToolUse"
    "PostToolUse"
    "SubagentStop"
    "UserPromptSubmit"
    "PreCompact"
  ];
in {
  home.packages = [pkgs.bun];

  # Live-editable TS handlers. Symlink the whole directory so adding files
  # under Notes/claude/hooks/ (e.g. additional helpers imported by index.ts)
  # shows up immediately without re-evaluating the module.
  home.file.".claude/hooks".source =
    config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/killuanix/Notes/claude/hooks";

  local.extraHooks = lib.genAttrs events mkEntry;
}
