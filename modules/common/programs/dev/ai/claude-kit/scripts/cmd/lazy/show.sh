#!/usr/bin/env bash
_lazy_show() {
  _lazy_parse_target "$@" || die "usage: claude-kit lazy show <type> <name>  |  show [<catalog>:]<name>  |  show <catalog>/<type>/<name>"
  local rc=0
  _lazy_resolve_one "$PARSED_TYPE" "$PARSED_NAME" "$PARSED_CAT" || rc=$?
  [ "$rc" = 0 ] || { _lazy_explain_rc "$rc" "$PARSED_TYPE" "$PARSED_NAME" "$PARSED_CAT"; exit 1; }
  local cat path
  cat="$RES_CAT"
  path="$RES_PATH"
  echo "catalog: $cat"
  echo "path:    $path"
  echo
  local file=""
  if [ -d "$path" ] && [ -f "$path/SKILL.md" ]; then file="$path/SKILL.md"
  elif [ -f "$path" ]; then file="$path"; fi
  if [ -n "$file" ]; then
    if [ -t 1 ]; then bat --style=plain --language=markdown --paging=auto "$file"
    else cat "$file"; fi
  fi
}
