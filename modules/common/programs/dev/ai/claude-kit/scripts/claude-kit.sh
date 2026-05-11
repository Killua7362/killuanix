#!/usr/bin/env bash
# claude-kit — entrypoint. Sets globals, sources libs, dispatches subcommand.

CLAUDE_DIR="${HOME}/.claude"
KIT_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/claude-kit"
SOURCES_DIR="${KIT_CACHE}/sources"
LAZY_DIR="${HOME}/killuanix/Notes/claude/lazy"

# shellcheck source=lib/common.sh
source "$CLAUDE_KIT_LIB_DIR/lib/common.sh"
# shellcheck source=lib/session.sh
source "$CLAUDE_KIT_LIB_DIR/lib/session.sh"
# shellcheck source=lib/lazy.sh
source "$CLAUDE_KIT_LIB_DIR/lib/lazy.sh"

usage() {
  cat <<'EOF'
claude-kit — manage Claude Code agents, commands, skills, plugins, and MCP servers.

Usage: claude-kit <subcommand> [args]

Browse installed resources (~/.claude/)
  list [agents|commands|skills|plugins|mcp|marketplaces|all]
                       List entries. Defaults to `all`.
  show <name>          Print an agent/command/skill's markdown (bat-rendered).
  search [query]       Filter installed resources. With no query, opens an
                       fzf picker with live preview.
  source <name>        Print the originating repo (ruflo / wshobson/<plugin>
                       / local) inferred from the filename prefix.

Flake-driven project sync (./claude-kit.nix)
  project sync [--dry-run] [--quiet]  Reconcile ./.claude/ + ./.mcp.json with
                                      the project's claude-kit.nix declarations.
                                      Auto-run from .envrc on direnv reload.
  project envrc                       Print `export VAR=val` for non-empty
                                      envVars (empty entries inherit from host).
  project show                        Print parsed claude-kit.nix as JSON.
  project status                      Show which items are flake-managed.

Per-project lazy catalog (Notes/claude/lazy/)
  lazy ls [<catalog>]                 List sub-catalogs or contents.
  lazy ls --type <kind>               Filter by skills|agents|commands|plugins.
  lazy show <type> <name>             Print item details.
  lazy add  <type> <name>             Symlink into cwd ./.claude/<type>/.
  lazy add  <catalog>/<type>/<name>   Disambiguate when name appears in multiple catalogs.
  lazy rm   <type> <name>             Remove from project scope.
  lazy project [--global]             List project-scope items (--global also shows catalog).
  lazy new <name>                     Scaffold a new sub-catalog dir.
  lazy refresh <name>                 Regenerate <name>/catalog.json from contents.
  lazy bundle ls|show|add|rm|status   Apply/remove named groups in one shot
                                      (e.g. `lazy bundle add ruflo`).
  lazy doctor                         Validate lazy.json and all catalog.json files.

Run a slash command headlessly
  run <command> [args] Execute `claude --print "/<command> args"` in cwd.

Two-stage prompt-to-plan
  plan "<prompt>"       Stage 1 picks a model+effort for your prompt; stage 2
  plan -f FILE          drafts a plan markdown with those settings in plan
  plan --help           mode. See `claude-kit plan --help` for the full flag
                        set (--output, --no-stage1, --model, --effort,
                        --dry-run).

Prune old conversations (keeps the 50 most recent per project)
  clean [-a|--all]     Delete `*.jsonl` files older than the 50 most recent
                       in the current project's `~/.claude/projects/<enc>/`
                       dir, plus their cached markdown previews. Prompts
                       before deleting; you must type `yes` exactly to
                       confirm. Default is the current project; `-a` widens
                       to every project.

Resume a past conversation (yazi-based picker)
  resume [-a] [-f]     Pick a session via yazi with markdown previews. Default
                       scope is the current project (cwd → encoded path under
                       ~/.claude/projects/); if cwd has no history, falls back
                       to all projects automatically. `-a` forces global scope.
                       Restricted UI by default: parent panel hidden, sorted
                       newest-first, parent-nav keys disabled. `-f` opens with
                       your normal yazi config (no restrictions).
                       Use yazi's open action to resume; Esc/q to abort.

Plugins (headless; shells out to `claude plugin …`)
  plugin list
  plugin install   <name>[@marketplace]
  plugin uninstall <name>[@marketplace]
  plugin enable    <name>[@marketplace]
  plugin disable   <name>[@marketplace]
  plugin update    [name]

Marketplaces (edits ~/.claude/settings.json directly)
  marketplace list
  marketplace add    <name> <github-owner/repo>
  marketplace remove <name>

MCP servers (pass-through to `claude mcp …`)
  mcp list
  mcp add <name> <command> [args…]
  mcp remove <name>
  mcp test   <name>

Misc
  ruflo [args…]        Pass-through to the ruflo CLI.
  doctor               Sanity check the install.
  version              Print pinned revs.
  help | -h | --help

Most resources are named `ruflo--…` (from ruvnet/ruflo) or
`wshobson--<plugin>--…` (from wshobson/agents). Use those names
verbatim with `show`, `run`, or Claude Code's slash autocomplete.
EOF
}

main() {
  local sub="${1:-help}"
  shift || true
  case "$sub" in
    help|-h|--help)       usage ;;
    list|ls)              source "$CLAUDE_KIT_LIB_DIR/cmd/list.sh";        cmd_list "$@" ;;
    show|cat)             source "$CLAUDE_KIT_LIB_DIR/cmd/show.sh";        cmd_show "$@" ;;
    search|s|find)        source "$CLAUDE_KIT_LIB_DIR/cmd/search.sh";      cmd_search "$@" ;;
    run)                  source "$CLAUDE_KIT_LIB_DIR/cmd/run.sh";         cmd_run "$@" ;;
    plan)                 source "$CLAUDE_KIT_LIB_DIR/cmd/plan.sh";        cmd_plan "$@" ;;
    resume|r)             source "$CLAUDE_KIT_LIB_DIR/cmd/resume.sh";      cmd_resume "$@" ;;
    clean)                source "$CLAUDE_KIT_LIB_DIR/cmd/clean.sh";       cmd_clean "$@" ;;
    plugin|plugins)       source "$CLAUDE_KIT_LIB_DIR/cmd/plugin.sh";      cmd_plugin "$@" ;;
    marketplace|market|mp) source "$CLAUDE_KIT_LIB_DIR/cmd/marketplace.sh"; cmd_marketplace "$@" ;;
    mcp)                  source "$CLAUDE_KIT_LIB_DIR/cmd/mcp.sh";         cmd_mcp "$@" ;;
    source|src)           source "$CLAUDE_KIT_LIB_DIR/cmd/source.sh";      cmd_source "$@" ;;
    ruflo)                source "$CLAUDE_KIT_LIB_DIR/cmd/ruflo.sh";       cmd_ruflo "$@" ;;
    lazy)                 source "$CLAUDE_KIT_LIB_DIR/cmd/lazy.sh";        cmd_lazy "$@" ;;
    project|proj)         source "$CLAUDE_KIT_LIB_DIR/cmd/project.sh";     cmd_project "$@" ;;
    doctor)               source "$CLAUDE_KIT_LIB_DIR/cmd/doctor.sh";      cmd_doctor ;;
    version|-V|--version) source "$CLAUDE_KIT_LIB_DIR/cmd/version.sh";     cmd_version ;;
    *) echo "claude-kit: unknown subcommand '$sub'" >&2; echo >&2; usage >&2; exit 2 ;;
  esac
}

main "$@"
