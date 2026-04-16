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
  lib,
  pkgs,
  ...
}: let
  registry = inputs.self.commonModules.mcpServers;
  mcp = inputs.mcp-servers-nix.packages.${pkgs.stdenv.hostPlatform.system};

  # List each root directory that contains skill subdirectories.
  # Every subdir of every root gets auto-imported — good for skill-only repos
  # like anthropics/skills. Add more flake-input repos or local paths here.
  skillRoots = [
    "${inputs.anthropics-skills}/skills"
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

  # Map each registry entry to a Claude Code mcpServers spec using the
  # mcp-servers-nix binary. `env`/`args` passthrough when set.
  mkClaudeServer = _: def:
    {command = lib.getExe mcp.${def.mcpServerNix};}
    // lib.optionalAttrs (def ? args) {inherit (def) args;}
    // lib.optionalAttrs (def ? env) {inherit (def) env;};
in {
  programs.claude-code = {
    enable = true;

    # Local skills override upstream on name clash (later foldl' entries win).
    skills = allSkills;

    mcpServers = lib.mapAttrs mkClaudeServer registry;
  };
}
