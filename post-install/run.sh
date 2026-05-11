#!/usr/bin/env bash
# Post-install dispatcher. See INSTRUCTIONS.md for the full runbook.
#
# Usage:
#   ./run.sh list              # show all step IDs and [x]/[ ] status
#   ./run.sh status            # alias for list
#   ./run.sh do <id>           # run a single step
#   ./run.sh all               # run every step in numeric order, skip done
#   ./run.sh reset <id>        # clear sentinel so step re-runs next time
#   ./run.sh reset-all         # clear ALL sentinels (asks for confirmation)
#   DRY_RUN=1 ./run.sh ...     # echo commands, change nothing

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$HERE/lib/common.sh"

usage() {
  sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

cmd_list() {
  printf '%shost:%s %s   %sstate:%s %s\n\n' \
    "$C_BOLD" "$C_RESET" "$HOSTNAME_SHORT" \
    "$C_BOLD" "$C_RESET" "$STATE_DIR"
  local id mark
  while read -r id; do
    if is_done "$id"; then
      mark="${C_GREEN}[x]${C_RESET}"
    else
      mark="${C_DIM}[ ]${C_RESET}"
    fi
    printf '  %s %s\n' "$mark" "$id"
  done < <(list_step_ids)
}

cmd_do() {
  local id="${1:-}"
  [[ -z "$id" ]] && { err "usage: run.sh do <id>"; exit 2; }
  run_step "$id"
}

cmd_all() {
  local id rc=0
  while read -r id; do
    run_step "$id" || rc=$?
  done < <(list_step_ids)
  return $rc
}

cmd_reset() {
  local id="${1:-}"
  [[ -z "$id" ]] && { err "usage: run.sh reset <id>"; exit 2; }
  reset_step "$id"
}

cmd_reset_all() {
  warn "this will clear every sentinel under $STATE_DIR"
  confirm "really reset all?" || { log "aborted"; return 0; }
  dry "rm -rf $STATE_DIR/*" && return 0
  rm -f "$STATE_DIR"/*.done
  ok "all sentinels cleared"
}

main() {
  local subcmd="${1:-list}"
  shift || true
  case "$subcmd" in
    list|status) cmd_list "$@" ;;
    do)          cmd_do "$@" ;;
    all)         cmd_all "$@" ;;
    reset)       cmd_reset "$@" ;;
    reset-all)   cmd_reset_all "$@" ;;
    -h|--help|help) usage ;;
    *) err "unknown subcommand: $subcmd"; usage; exit 2 ;;
  esac
}

main "$@"
