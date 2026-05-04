#!/usr/bin/env bash
cmd_search() {
  local query="${1:-}"
  local all
  all=$({
    _list_agents   | sed 's/^/agent   /'
    _list_commands | sed 's/^/command /'
    _list_skills   | sed 's/^/skill   /'
  })
  if [ -z "$query" ]; then
    if [ ! -t 0 ] || [ ! -t 1 ]; then
      echo "$all"; return 0
    fi
    echo "$all" | fzf --preview 'claude-kit show {2}' \
                      --preview-window=right:60%:wrap \
                      --header 'Type to filter · Enter to show · Esc to quit'
  else
    echo "$all" | grep -i -- "$query" || { echo "no matches for: $query" >&2; return 1; }
  fi
}
