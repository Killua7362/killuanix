#!/usr/bin/env bash
cmd_run() {
  local name="${1:-}"
  [ -n "$name" ] || die "usage: claude-kit run <command> [args…]"
  shift
  exec claude --print "/${name} $*"
}
