# claude-news — Claude Code scoped to FreshRSS news reading + Q&A.
#
# Wires the freshrss MCP (Greader API client, registered as `optional` in
# freshrss-mcp/default.nix) plus fetch (for full article bodies) and
# basic-memory (so notes / takeaways can be stashed into
# Notes/claude/memory/). Slash commands (`/digest`, `/ask-news`,
# `/starred`) live in `Notes/claude/lazy/personal/commands/` (so they
# do NOT auto-load globally) and are symlinked into the launcher's
# state dir at launch — visible only when running `claude-news`. Paths
# are passed as strings (via `notesCmd`), not nix `./...` paths, so
# content edits propagate live without `scripts/nix_switch`.
#
# `inheritGlobal = false` keeps the MCP set lean (no mermaid /
# filesystem / memory leaking in). `restrictToDirs` pins
# `permissions.additionalDirectories` to Notes so Claude's built-in
# Read/Write/Edit tools stay scoped there, and adds advisory deny rules
# for ssh / sops / etc. Add `"filesystem"` to `mcp` here if you also want
# a sandboxed filesystem MCP (its args get narrowed to restrictToDirs
# automatically).
{
  config,
  inputs,
  lib,
  pkgs,
  notesCmd,
  ...
}: {
  name = "claude-news";
  stateName = "news";

  # --- Additive layers ---

  skills = {};

  agents = {};

  # Slash commands sourced from the personal lazy catalog.
  commands = {
    digest = notesCmd "digest";
    ask-news = notesCmd "ask-news";
    starred = notesCmd "starred";
  };

  plugins = [];

  # With inheritGlobal=false this list is the WHOLE MCP set for the
  # launcher. Add "filesystem" here too if you want filesystem MCP access
  # constrained to restrictToDirs.
  mcp = [
    "freshrss"
    "fetch"
    "basic-memory"
  ];

  # --- Composition mode ---

  # false → total replacement: only resources declared here are wired in.
  # No global skills / agents / commands / MCPs leak through. Use this
  # mode for sandbox launchers where the surface should be minimal.
  inheritGlobal = false;

  # --- Subtractive layers (no-op with inheritGlobal=false; listed for
  #     symmetry / documentation) ---

  excludeSkills = [];
  excludeAgents = [];
  excludeCommands = [];
  excludePlugins = [];
  excludeMcp = [];

  # --- settings.permissions extras ---

  allowedTools = [];

  # Extra denies on top of the sensitive-path defaults that restrictToDirs
  # already adds. Uncomment to block exfil tools.
  deniedTools = [];
  # deniedTools = [
  #   "Bash(curl:*)"
  #   "Bash(wget:*)"
  #   "WebFetch"
  # ];

  # --- Hooks ---

  # null → no hooks (global hooks not inherited either, since
  # inheritGlobal=false bypasses the global Stop hook etc.).
  hooks = null;

  # --- Filesystem restriction ---

  # Pin the launcher to the Notes vault. Claude's Read/Write/Edit honor
  # additionalDirectories; sensitive-path Read denies block ssh/sops/etc.
  restrictToDirs = [
    "${config.home.homeDirectory}/killuanix/Notes"
  ];

  # --- Model / effort pins ---

  model = null;
  effort = null;
}
