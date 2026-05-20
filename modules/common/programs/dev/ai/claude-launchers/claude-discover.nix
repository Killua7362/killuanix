# claude-discover — Claude Code scoped to discovering MCP servers / skills /
# plugins / subagents across multiple registries.
#
# Wires `kindly-web-search` (SearXNG + headless chromium for page extraction),
# `fetch` (raw JSON registry API hits), and `basic-memory` (stash findings to
# Notes/claude/memory/). The `discover-resource` skill at
# `Notes/claude/lazy/personal/skills/discover-resource/` carries the research
# playbook (registry list + per-type query strategy). `/find <use-case>` is
# the user-facing entrypoint; the skill body lays out the steps. With
# `inheritGlobal = false` the rest of the global skill / MCP set is left out
# so discovery sessions stay lean.
#
# `restrictToDirs` pins the writable surface to Notes + the local resource
# catalog dirs so the skill's "Step 0 — check local first" pass can read
# `$XDG_DATA_HOME/claude-kit/all-mcp-servers.json` and the lazy sub-catalogs
# without prompts. Sensitive-path deny rules (ssh / sops / age / etc.) are
# appended automatically by the `restrictToDirs` logic in `default.nix`.
{
  config,
  inputs,
  lib,
  pkgs,
  notesCmd,
  ...
}: {
  name = "claude-discover";
  stateName = "discover";

  # --- Additive layers ---

  skills = {
    discover-resource = "${config.home.homeDirectory}/killuanix/Notes/claude/lazy/personal/skills/discover-resource";
  };

  agents = {};

  commands = {
    find = notesCmd "find";
  };

  plugins = [];

  # With inheritGlobal=false this list is the WHOLE MCP set for the launcher.
  mcp = [
    "kindly-web-search"
    "fetch"
    "basic-memory"
  ];

  # --- Composition mode ---

  inheritGlobal = false;

  # --- Subtractive layers (no-op with inheritGlobal=false; listed for symmetry) ---

  excludeSkills = [];
  excludeAgents = [];
  excludeCommands = [];
  excludePlugins = [];
  excludeMcp = [];

  # --- settings.permissions extras ---

  # Pre-approve the read-only investigative commands the discover-resource
  # skill drives. `gh api` pulls marketplace.json + READMEs from public repos;
  # `jq` parses the responses; `claude-kit` surfaces the local catalog.
  allowedTools = [
    "Bash(gh:*)"
    "Bash(jq:*)"
    "Bash(claude-kit:*)"
    "WebFetch"
  ];

  deniedTools = [];

  # --- Hooks ---

  hooks = null;

  # --- Filesystem restriction ---

  # Notes + local catalog dirs. Notes is writable so basic-memory can stash
  # findings and the user can drop newly-discovered skills into
  # Notes/claude/lazy/personal/. Read access to the claude-kit catalog
  # is required for Step 0 of the skill.
  restrictToDirs = [
    "${config.home.homeDirectory}/killuanix/Notes"
    "${config.home.homeDirectory}/.local/share/claude-kit"
    "${config.home.homeDirectory}/.cache/claude-kit"
  ];

  # --- Model / effort pins ---

  model = null;
  effort = "high";
}
