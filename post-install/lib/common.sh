#!/usr/bin/env bash
# Sourced by run.sh and every step script.
# Provides: log, warn, err, has_cmd, confirm, sentinel paths, step wrapper.

set -uo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/..}"
REPO_ROOT="$(cd "$REPO_ROOT" && pwd)"
STEPS_DIR="$REPO_ROOT/post-install/steps"
HOSTNAME_SHORT="$(hostname -s 2>/dev/null || hostname)"
STATE_BASE="${XDG_STATE_HOME:-$HOME/.local/state}/killuanix-postinstall"
STATE_DIR="$STATE_BASE/$HOSTNAME_SHORT"
mkdir -p "$STATE_DIR"

DRY_RUN="${DRY_RUN:-0}"

if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'
  C_DIM=$'\033[2m'
  C_BOLD=$'\033[1m'
  C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'
else
  C_RESET=""; C_DIM=""; C_BOLD=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""
fi

log()  { printf '%s[*]%s %s\n' "$C_BLUE"   "$C_RESET" "$*"; }
ok()   { printf '%s[ok]%s %s\n' "$C_GREEN"  "$C_RESET" "$*"; }
warn() { printf '%s[!]%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
err()  { printf '%s[x]%s %s\n' "$C_RED"    "$C_RESET" "$*" >&2; }
hint() { printf '%s    %s%s\n' "$C_DIM"    "$*"      "$C_RESET"; }

has_cmd() { command -v "$1" >/dev/null 2>&1; }

confirm() {
  local prompt="${1:-Continue?}" reply
  if [[ "$DRY_RUN" == "1" ]]; then
    log "DRY_RUN: would prompt: $prompt"
    return 0
  fi
  read -r -p "$prompt [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

dry() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '%s[dry]%s %s\n' "$C_DIM" "$C_RESET" "$*"
    return 0
  fi
  return 1
}

# sentinel_path <id>
sentinel_path() { printf '%s/%s.done\n' "$STATE_DIR" "$1"; }

is_done() { [[ -e "$(sentinel_path "$1")" ]]; }

mark_done() {
  local id="$1"
  dry "touch $(sentinel_path "$id")" && return 0
  date -Iseconds > "$(sentinel_path "$id")"
}

reset_step() {
  local id="$1" path
  path="$(sentinel_path "$id")"
  if [[ -e "$path" ]]; then
    dry "rm $path" && return 0
    rm -f "$path"
    ok "reset $id"
  else
    warn "$id was not marked done"
  fi
}

# Each step script defines `run` and is sourced by run_step.
run_step() {
  local id="$1" script
  script="$STEPS_DIR/$id.sh"
  if [[ ! -f "$script" ]]; then
    err "no step script: $script"
    return 2
  fi
  if is_done "$id"; then
    ok "skip $id (already done — $(cat "$(sentinel_path "$id")"))"
    return 0
  fi
  log "run  $id"
  # shellcheck disable=SC1090
  ( source "$script" && run )
  local rc=$?
  if [[ $rc -eq 0 ]]; then
    mark_done "$id"
    ok "done $id"
  else
    err "$id failed (exit $rc)"
  fi
  return $rc
}

list_step_ids() {
  find "$STEPS_DIR" -maxdepth 1 -type f -name '*.sh' -printf '%f\n' \
    | sed 's/\.sh$//' | sort
}
