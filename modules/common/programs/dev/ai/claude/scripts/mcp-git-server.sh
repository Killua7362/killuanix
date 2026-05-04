#!/usr/bin/env bash
# Wrapper executed by Claude Code for git-sourced MCP servers.
# Copies the read-only nix-store source into a writable per-user workdir
# (so uv/pipx/npm can manage venvs and node_modules) and execs the runtime.
#
# Workdir is keyed by store-path hash, so rev bumps and patch edits both
# invalidate the previous copy.
#
# Inputs (env vars set by the writeShellApplication wrapper in ../claude.nix):
#   MCP_NAME       — server name (used in workdir path)
#   MCP_SRCKEY     — 12-char store-path hash of the (possibly patched) source
#   MCP_SRC        — absolute store path to the source tree
#   MCP_RUNTIME    — currently must be "uv-run"
#   MCP_ENTRYPOINT — relative path to the runtime entrypoint inside the source
set -euo pipefail

workdir="${XDG_CACHE_HOME:-$HOME/.cache}/mcp-servers/$MCP_NAME-$MCP_SRCKEY"
if [ ! -e "$workdir/.ready" ]; then
  mkdir -p "$workdir"
  cp -rL --no-preserve=mode,ownership "$MCP_SRC/." "$workdir/"
  touch "$workdir/.ready"
fi
cd "$workdir"

case "$MCP_RUNTIME" in
  uv-run)
    exec uv run python "$MCP_ENTRYPOINT" "$@"
    ;;
  *)
    echo "mcp-git-server: unsupported runtime '$MCP_RUNTIME'" >&2
    exit 2
    ;;
esac
