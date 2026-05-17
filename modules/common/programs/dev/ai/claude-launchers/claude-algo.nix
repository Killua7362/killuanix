# claude-algo — Claude Code with the algo-sensei skill from
# karanb192/algo-sensei (pinned as `inputs.algo-sensei`) layered on top of
# the global config. Everything else (skills, agents, commands, MCPs,
# plugins, hooks) is inherited from `~/.claude/`.
{
  config,
  inputs,
  lib,
  pkgs,
  notesCmd,
  ...
}: {
  name = "claude-algo";
  stateName = "algo";

  # --- Additive layers (added ON TOP of the inherited global set when
  #     inheritGlobal = true; the only resources visible when false) ---

  # Extra skills. Each entry: <name> = <path-to-dir-containing-SKILL.md>.
  # Becomes `~/.claude/skills/<name>/` inside the launcher state dir.
  skills = {
    algo-sensei = inputs.algo-sensei;
  };

  # Extra agents. Each entry: <name> = <path-to-md-file>.
  # Becomes `~/.claude/agents/<name>.md` inside the launcher state dir.
  agents = {};

  # Extra slash commands. Each entry: <name> = <path-to-md-file>.
  # Becomes `~/.claude/commands/<name>.md` inside the launcher state dir.
  # Use `notesCmd "foo"` to point at a live file under Notes/.../commands/
  # (content edits propagate without `scripts/nix_switch`).
  commands = {};

  # Extra plugin slugs to flip to true in settings.json.enabledPlugins.
  # Format: "<plugin@source>" (e.g. "ruflo-core@ruflo").
  plugins = [];

  # Extra MCP server names to resolve from the claude-kit catalog and add
  # to the launcher's inline plugin .mcp.json. Names match keys in
  # `modules/common/mcp-servers.nix` (or `local.extraMcpServers`).
  mcp = [];

  # --- Composition mode ---

  # When true (default), inherit the global skills/agents/commands set
  # from ~/.claude/, the global enabledPlugins block, and the non-optional
  # MCPs from the claude-kit catalog. The lists above LAYER ON TOP. When
  # false, only the lists above are wired (legacy "total replacement"; use
  # for sandbox launchers like claude-news).
  inheritGlobal = true;

  # --- Subtractive layers (only meaningful with inheritGlobal = true) ---

  # Drop these skill names from the inherited ~/.claude/skills/ mirror.
  # Bare names — no trailing slash.
  excludeSkills = [];

  # Drop these agent names from the inherited ~/.claude/agents/ mirror.
  # Bare names — no `.md` extension.
  excludeAgents = [];

  # Drop these command names from the inherited ~/.claude/commands/ mirror.
  # Bare names — no `.md` extension.
  excludeCommands = [];

  # Delete these plugin keys from enabledPlugins (revert to global default).
  # Format same as `plugins`: "<plugin@source>".
  excludePlugins = [];

  # Drop these MCP server names from the inherited global catalog set.
  # E.g. `[ "mermaid" ]` to keep everything global except mermaid.
  excludeMcp = [];

  # --- settings.permissions extras (merged into the inherited base) ---

  # Appended to settings.permissions.allow (deduped). Pattern syntax matches
  # Claude Code's permission grammar — e.g. "Bash(rg:*)", "Read(/etc/**)",
  # "WebFetch", "mcp__mermaid__*".
  allowedTools = [];

  # Appended to settings.permissions.deny (deduped). Same syntax as above.
  deniedTools = [];

  # --- Hooks ---

  # Per-launcher hooks. When non-null, REPLACES the inherited global hooks
  # block wholesale (intentional isolation — e.g. skip the global caveman
  # Stop hook). Same shape as programs.claude-code.settings.hooks. Leave
  # null to inherit globals.
  hooks = null;
  # hooks = {
  #   Stop = [{
  #     hooks = [{ type = "command"; command = "echo bye"; timeout = 5; }];
  #   }];
  # };

  # --- Filesystem restriction (sandbox-style launchers only) ---

  # When non-null:
  #   * settings.permissions.additionalDirectories = this list (Claude's
  #     built-in Read/Write/Edit honor it).
  #   * If the launcher's `mcp` list includes "filesystem", the server's
  #     args are rewritten to this list — the upstream MCP server itself
  #     refuses paths outside its roots (strict half).
  #   * Sensitive-path deny patterns (~/.ssh, ~/.gnupg, sops, age, /etc,
  #     /var, /root) are appended to permissions.deny (advisory half).
  # null = no narrowing (default — full access).
  restrictToDirs = null;
  # restrictToDirs = [ "${config.home.homeDirectory}/some/sandbox" ];

  # --- Model / effort pins (optional) ---

  # When non-null, jq-pinned into settings.json on every launch. Use to
  # override the global default for sessions started via this launcher.
  # Caveat: in-session `/model` switches still leak to ~/.claude.json
  # (shared file); the startup pin is enforced, runtime sovereignty isn't.
  model = null;
  # model = "claude-opus-4-7";

  # When non-null, jq-pinned into settings.json on every launch.
  # "low" | "medium" | "high" | "xhigh" | "auto" ("max" is transient-only).
  effort = null;
  # effort = "low";
}
