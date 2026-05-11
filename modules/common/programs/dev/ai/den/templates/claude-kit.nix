# Project-scoped Claude Code resources.
#
# Read by `claude-kit project sync` (auto-run from .envrc) to reconcile
# this project's ./.claude/ directory and ./.mcp.json against the
# declarations below. Global skills and MCP servers (from ~/.claude/)
# stay loaded — these lists are purely additive.
#
# Pure attrset — no `inputs`, no `pkgs`, no `lib`. Evaluated with
# `nix-instantiate --eval --strict --json` (no flake context needed).
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
}
