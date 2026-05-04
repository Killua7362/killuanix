#!/usr/bin/env bash
# Shared helpers for claude-kit: logging, listing primitives, file resolution.

die() { echo "claude-kit: $*" >&2; exit 1; }

_list_agents()   { [ -d "$CLAUDE_DIR/agents" ]   && find "$CLAUDE_DIR/agents"   -maxdepth 1 -type l -o -type f -name '*.md' 2>/dev/null | sed 's|.*/||; s|\.md$||' | sort; }
_list_commands() { [ -d "$CLAUDE_DIR/commands" ] && find "$CLAUDE_DIR/commands" -maxdepth 1 -type l -o -type f -name '*.md' 2>/dev/null | sed 's|.*/||; s|\.md$||' | sort; }
_list_skills()   { [ -d "$CLAUDE_DIR/skills" ]   && find "$CLAUDE_DIR/skills"   -mindepth 1 -maxdepth 1 \( -type d -o -type l \) 2>/dev/null | sed 's|.*/||' | sort; }

_resolve_file() {
  local name="$1"
  local base="${name%.md}"
  if [ -f "$CLAUDE_DIR/agents/${base}.md" ]; then
    echo "$CLAUDE_DIR/agents/${base}.md"; return 0
  fi
  if [ -f "$CLAUDE_DIR/commands/${base}.md" ]; then
    echo "$CLAUDE_DIR/commands/${base}.md"; return 0
  fi
  if [ -f "$CLAUDE_DIR/skills/${base}/SKILL.md" ]; then
    echo "$CLAUDE_DIR/skills/${base}/SKILL.md"; return 0
  fi
  return 1
}
