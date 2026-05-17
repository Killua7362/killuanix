# Project-scoped Claude Code resources.
#
# Read by `claude-kit project sync` (auto-run from .envrc) to reconcile
# this project's ./.claude/ directory and ./.mcp.json against the
# declarations below. Global skills and MCP servers (from ~/.claude/)
# stay loaded — these lists are purely additive.
#
# Edit by hand, or let the CLI manage it: `claude-kit lazy add <type>
# <name>` (and `lazy rm`, `lazy bundle add/rm`) auto-detect this file
# and edit the relevant list in place, then re-sync. Pass `--imperative`
# to bypass and write `./.claude/` directly.
#
# Pure attrset — no `inputs`, no `pkgs`, no `lib`. Evaluated with
# `nix-instantiate --eval --strict --json` (no flake context needed).
# Keep one entry per line so the CLI mutator can edit safely.
{
  # envVars — exported into the dev shell on direnv reload.
  #
  # Non-empty values are exported. Empty strings are skipped, so the
  # parent shell's value (if any) flows through unchanged. Use this
  # for project-specific knobs (APP_HOST = "killua") and for secrets
  # that should come from the host environment (OPENAI_API_KEY = "").
  envVars = {
    # APP_HOST = "killua";
    # DATABASE_URL = "";       # empty → inherit from parent shell
    # OPENAI_API_KEY = "";     # empty → inherit
  };

  # Names match entries in the lazy catalog (Notes/claude/lazy/<cat>/).
  # Disambiguate with "<catalog>/<name>" when the same name exists in
  # multiple catalogs.
  skills = [
    # "code-search"
    # "obsidian-vault"
  ];

  agents = [
    # "personal/code-reviewer"
  ];

  commands = [
    # "personal/release-notes"
  ];

  # Plugin slugs as recognised by `claude-kit lazy add plugin <slug>`
  # (e.g. "ruflo-core@ruflo"). Written to ./.claude/settings.local.json.
  plugins = [
    # "ruflo-core@ruflo"
  ];

  # MCP server names from the user's global registry (resolved via
  # ~/.claude.json). Each named server is copied into ./.mcp.json.
  mcp = [
    # "code-index"
    # "basic-memory"
  ];

  # ----------------------------------------------------------------------
  # Exclusion + per-project permissions + hooks + filesystem narrowing.
  #
  # These attrs all write into ./.claude/settings.local.json so the project
  # session can opt OUT of globally-loaded resources or harden its own
  # surface. Settings layer over `~/.claude/settings.json`, so this is the
  # right place to encode "in this project, don't load mermaid" or "in this
  # project, only allow Read/Write inside Notes".
  # ----------------------------------------------------------------------

  # Block named globally-loaded MCP servers from being used in this project.
  # Each entry becomes a `"mcp__<name>__*"` rule in
  # settings.local.json.permissions.deny. Effective for ANY globally-loaded
  # server (mermaid, filesystem, …) that the user wants disabled per-project.
  excludeMcp = [
    # "mermaid"
  ];

  # Plugin slugs to disable in this project even if globally enabled.
  # Each entry becomes `enabledPlugins."<slug>" = false` in
  # settings.local.json. (Plugins that aren't globally enabled stay alone.)
  excludePlugins = [
    # "ruflo-core@ruflo"
  ];

  # Advisory exclusion of globally-loaded skills / agents / commands.
  # Claude Code does not currently expose a strict per-project block for
  # these (they're loaded from ~/.claude/). The names listed here are
  # accepted by `claude-kit project sync` for symmetry with the launcher
  # schema and so the project's CLAUDE.md / settings file can document the
  # intent; effective enforcement is the user's responsibility (e.g. lift
  # the unwanted skill out of `~/.claude/skills/` globally, or add a
  # corresponding `deniedTools` rule below).
  excludeSkills   = [ ];
  excludeAgents   = [ ];
  excludeCommands = [ ];

  # Extra tool permissions, appended into settings.local.json:permissions.
  # Pattern syntax matches Claude Code's own permission grammar — e.g.
  # "Bash(curl:*)", "Read(/etc/**)", "WebFetch", "mcp__mermaid__*".
  allowedTools = [
    # "Bash(rg:*)"
  ];
  deniedTools = [
    # "Bash(curl:*)"
    # "WebFetch"
  ];

  # Per-project hooks. Same shape as programs.claude-code.settings.hooks.
  # Written verbatim into settings.local.json:hooks. Project-level hooks
  # MERGE with global hooks at Claude Code's runtime (both fire). Use this
  # to add project-specific lifecycle hooks; use null to inherit globals.
  hooks = null;
  # hooks = {
  #   Stop = [{
  #     hooks = [{ type = "command"; command = "echo project stop"; }];
  #   }];
  # };

  # Filesystem narrowing for sandbox-style projects. When non-null:
  #   * settings.local.json.permissions.additionalDirectories = this list
  #     (Claude's built-in Read/Write/Edit honor it).
  #   * If the project's `mcp = [...]` declares "filesystem", its args are
  #     rewritten to this list — the upstream MCP server itself refuses
  #     paths outside its roots.
  #   * Deny patterns for well-known sensitive paths (~/.ssh, ~/.gnupg,
  #     ~/.config/sops, ~/.config/age, /etc/**, /var/**, /root/**) are
  #     appended to settings.local.json.permissions.deny.
  # null = no narrowing (default — full access).
  restrictToDirs = null;
  # restrictToDirs = [ "/home/killua/killuanix/Notes" ];
}
