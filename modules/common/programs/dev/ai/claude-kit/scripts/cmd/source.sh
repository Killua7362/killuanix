#!/usr/bin/env bash
cmd_source() {
  local name="${1:-}"
  [ -n "$name" ] || die "usage: claude-kit source <name>"
  local base="${name%.md}"
  case "$base" in
    ruflo--*)    echo "ruflo" ;;
    wshobson--*) rest="${base#wshobson--}"; echo "wshobson/${rest%%--*}" ;;
    *)           echo "local" ;;
  esac
}
