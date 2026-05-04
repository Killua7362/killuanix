#!/usr/bin/env bash
cmd_show() {
  local name="${1:-}"
  [ -n "$name" ] || die "usage: claude-kit show <name>"
  local f
  f=$(_resolve_file "$name") || die "not found: $name"
  if [ -t 1 ]; then
    bat --style=plain --language=markdown --paging=auto "$f"
  else
    cat "$f"
  fi
}
