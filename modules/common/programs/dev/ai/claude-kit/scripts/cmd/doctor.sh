#!/usr/bin/env bash
cmd_doctor() {
  local ok=1
  check() {
    if eval "$2" >/dev/null 2>&1; then
      printf '  [ok]   %s\n' "$1"
    else
      printf '  [FAIL] %s\n' "$1"; ok=0
    fi
  }
  echo "claude-kit doctor:"
  check "claude on PATH"                 "command -v claude"
  check "ruflo on PATH"                  "command -v ruflo"
  # shellcheck disable=SC2088
  check "~/.claude/agents populated"     "[ -n \"\$(ls -A \"$CLAUDE_DIR/agents\" 2>/dev/null)\" ]"
  # shellcheck disable=SC2088
  check "~/.claude/commands populated"   "[ -n \"\$(ls -A \"$CLAUDE_DIR/commands\" 2>/dev/null)\" ]"
  # shellcheck disable=SC2088
  check "~/.claude/skills populated"     "[ -n \"\$(ls -A \"$CLAUDE_DIR/skills\" 2>/dev/null)\" ]"
  check "sources cache linked"           "[ -e \"$SOURCES_DIR/agents.link\" ] && [ -e \"$SOURCES_DIR/commands.link\" ] && [ -e \"$SOURCES_DIR/skills.link\" ]"
  check "lazy dir present"               "[ -d \"$LAZY_DIR\" ]"
  check "lazy upstream catalog"          "[ -f \"$LAZY_DIR/upstream/catalog.json\" ]"
  [ "$ok" = 1 ]
}
