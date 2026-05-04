#!/usr/bin/env bash
cmd_list() {
  local kind="${1:-all}"
  case "$kind" in
    agents)       _list_agents ;;
    commands)     _list_commands ;;
    skills)       _list_skills ;;
    plugins)      claude plugin list ;;
    mcp)          claude mcp list ;;
    marketplaces)
      if [ -f "$CLAUDE_DIR/settings.json" ]; then
        jq -r '(.extraKnownMarketplaces // {}) | to_entries[] | "\(.key)\t\(.value.source.repo // .value.source.url // "(source unknown)")"' "$CLAUDE_DIR/settings.json"
      else
        echo "(no settings.json)"
      fi ;;
    all|"")
      echo "=== agents ($( _list_agents   | wc -l )) ===";   _list_agents
      echo
      echo "=== commands ($( _list_commands | wc -l )) ==="; _list_commands
      echo
      echo "=== skills ($( _list_skills   | wc -l )) ==="; _list_skills ;;
    *) die "unknown kind: $kind (try agents|commands|skills|plugins|mcp|marketplaces)" ;;
  esac
}
