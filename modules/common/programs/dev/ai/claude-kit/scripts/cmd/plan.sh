#!/usr/bin/env bash
# claude-kit plan — two-stage prompt-to-plan (suggestion → plan markdown).
#
# Implementation lives in the python sidecar at ../../plan/. The wrapper
# in default.nix exports CLAUDE_KIT_PLAN_BIN to its venv entry point.

cmd_plan() {
  if [ -z "${CLAUDE_KIT_PLAN_BIN:-}" ]; then
    echo "claude-kit plan: CLAUDE_KIT_PLAN_BIN is unset (broken install)" >&2
    return 1
  fi
  exec "$CLAUDE_KIT_PLAN_BIN" "$@"
}
