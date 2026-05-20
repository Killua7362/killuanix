#!/usr/bin/env bash
# Generate the ruflo catalog's bundles/ — named groups of plugins / MCP /
# catalog items that `claude-kit lazy bundle add <name>` activates per-project
# in one shot.
#
# The `ruflo` bundle mirrors the plugin set that used to live in claude.nix
# `enabledPlugins` before the lazy migration. Plugins are listed by their
# `<name>@<marketplace>` form; claude-kit resolves them via the marketplace
# registered globally in claude.nix (`extraKnownMarketplaces`).
#
# MCP servers are intentionally empty — `ruflo init` already writes
# `.mcp.json` with the claude-flow entry, so including an MCP entry would
# just duplicate that.
#
# Inputs:
#   out — runCommand output dir
set -euo pipefail

mkdir -p "$out"

jq -n '{
  name: "ruflo",
  description: "Full ruflo plugin stack (8 plugins). Run after `ruflo init`, which writes `.mcp.json` with claude-flow.",
  plugins: [
    "ruflo-core@ruflo",
    "ruflo-swarm@ruflo",
    "ruflo-autopilot@ruflo",
    "ruflo-loop-workers@ruflo",
    "ruflo-security-audit@ruflo",
    "ruflo-rag-memory@ruflo",
    "ruflo-testgen@ruflo",
    "ruflo-docs@ruflo"
  ],
  mcp: {},
  skills: [],
  agents: [],
  commands: []
}' > "$out/ruflo.json"
