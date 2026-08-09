#!/usr/bin/env bash
_lazy_ls() {
  local catalog="" type_filter=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --type) type_filter="${2:-}"; shift 2 ;;
      -h|--help) _lazy_help; return 0 ;;
      -*) die "lazy ls: unknown flag $1" ;;
      *)  catalog="$1"; shift ;;
    esac
  done

  # Top-level: list catalogs with item counts.
  if [ -z "$catalog" ] && [ -z "$type_filter" ]; then
    local any=0 c
    for c in $(_lazy_catalogs); do
      any=1
      local s a cm p desc=""
      s=$(_lazy_count "$c" skills)
      a=$(_lazy_count "$c" agents)
      cm=$(_lazy_count "$c" commands)
      p=$(_lazy_count "$c" plugins)
      if [ -f "$LAZY_DIR/lazy.json" ]; then
        desc=$(jq -r --arg c "$c" '(.catalogs[$c].description // "")' "$LAZY_DIR/lazy.json" 2>/dev/null)
      fi
      if [ -n "$desc" ]; then
        printf '%-12s skills=%-4s agents=%-4s commands=%-4s plugins=%-3s  %s\n' "$c" "$s" "$a" "$cm" "$p" "$desc"
      else
        printf '%-12s skills=%-4s agents=%-4s commands=%-4s plugins=%-3s\n' "$c" "$s" "$a" "$cm" "$p"
      fi
    done
    [ "$any" = 1 ] || echo "(no catalogs in $LAZY_DIR)"
    return 0
  fi

  # Specific catalog + type filter.
  if [ -n "$catalog" ] && [ -n "$type_filter" ]; then
    [ -f "$LAZY_DIR/$catalog/catalog.json" ] || die "no such catalog: $catalog"
    _lazy_catalog_json "$catalog" | jq -r --arg t "$type_filter" '(.[$t] // []) | .[] | .name'
    return 0
  fi

  # Whole catalog (all types).
  if [ -n "$catalog" ]; then
    [ -f "$LAZY_DIR/$catalog/catalog.json" ] || die "no such catalog: $catalog"
    local cj; cj=$(_lazy_catalog_json "$catalog")
    local t
    for t in skills agents commands plugins; do
      local n; n=$(printf '%s' "$cj" | jq -r --arg t "$t" '(.[$t] // []) | length')
      [ "$n" -gt 0 ] || continue
      echo "=== $catalog/$t ($n) ==="
      printf '%s' "$cj" | jq -r --arg t "$t" '(.[$t] // []) | .[] | "  " + .name'
    done
    return 0
  fi

  # --type across all catalogs.
  if [ -n "$type_filter" ]; then
    local c
    for c in $(_lazy_catalogs); do
      _lazy_catalog_json "$c" | jq -r --arg t "$type_filter" --arg c "$c" \
        '(.[$t] // []) | .[] | "\($c)/" + .name'
    done | sort
  fi
}
