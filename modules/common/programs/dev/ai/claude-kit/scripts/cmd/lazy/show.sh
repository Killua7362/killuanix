#!/usr/bin/env bash
_lazy_show() {
  _lazy_parse_target "$@" || die "usage: claude-kit lazy show <type> <name>  |  show <catalog>/<type>/<name>"
  local matches
  matches=$(_lazy_find "$PARSED_TYPE" "$PARSED_NAME" "$PARSED_CAT")
  local n; n=$(printf '%s' "$matches" | grep -c . 2>/dev/null || true)
  if [ "$n" = 0 ] || [ -z "$matches" ]; then die "not found: $PARSED_TYPE/$PARSED_NAME"; fi
  if [ "$n" -gt 1 ]; then
    echo "lazy: multiple matches:" >&2
    printf '%s\n' "$matches" | awk '{print "  " $1 "/" }' >&2
    die "use <catalog>/$PARSED_TYPE/$PARSED_NAME to disambiguate"
  fi
  local cat path
  cat=$(printf '%s' "$matches" | awk '{print $1}')
  path=$(printf '%s' "$matches" | awk '{print $2}')
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
