# RTK (Rust Token Killer) — declarative Claude Code PreToolUse hook.
#
# The `rtk` binary itself is installed via `commonPackages` (packages.nix).
# Upstream's `rtk init -g` writes a shell hook (rtk-rewrite.sh + jq + a version
# cache) into ~/.claude/settings.json imperatively — but `~/.claude/settings.json`
# is a read-only nix-store symlink here, and we don't want imperative state.
#
# Instead we register rtk's native single-binary hook processor
# (`rtk hook claude`, added upstream in 0.23.0 — reads the PreToolUse JSON on
# stdin, emits the `hookSpecificOutput.updatedInput` rewrite on stdout, exits 0
# and prints nothing when a command has no RTK equivalent) through the shared
# `local.extraHooks` side-channel declared in claude.nix. No jq, no external
# script, no version cache — the hook binary is the same nix-pinned rtk, so it
# can never drift from the installed version. This fully replaces `rtk init -g`.
#
# The `matcher = "Bash"` scopes the rewrite to the Bash tool only. The entry
# concatenates (does not clobber) with other PreToolUse contributors because
# `local.extraHooks` is a `listOf`.
#
# Note: on a rewrite `rtk hook claude` prints a one-time "[rtk] no hook
# installed" nag to *stderr* (stdout stays clean JSON, so the hook is not
# corrupted). Once this hook lands in the rendered settings.json, rtk's own
# self-detection sees a settings entry referencing `rtk` and stops nagging.
{
  pkgs,
  lib,
  ...
}: let
  rtk = pkgs.callPackage ../../../../../packages/rtk/package.nix {};
in {
  local.extraHooks.PreToolUse = [
    {
      matcher = "Bash";
      hooks = [
        {
          type = "command";
          command = "${lib.getExe rtk} hook claude";
          timeout = 10;
        }
      ];
    }
  ];
}
