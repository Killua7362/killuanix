#!/usr/bin/env bash
# `lazy doctor [--strict] [--quiet]` — validate the whole lazy catalog tree.
#
# Runs a battery of checks over lazy.json and every <catalog>/catalog.json:
# JSON well-formedness, structural shape, per-entry integrity (name/path,
# dead paths, wrong file kind, duplicates), `inherit` wiring (missing/self/
# cycle sources, include/exclude names that don't exist upstream), plus
# cross-file consistency with lazy.json. Meant to be run in CI / pre-commit.
#
#   --strict   treat warnings as failures (non-zero exit if any [WARN]).
#   --quiet    print only [WARN]/[FAIL] lines + the summary (suppress [ok]).
#
# Exit: 0 if no [FAIL] (and, under --strict, no [WARN]); 1 otherwise.

_lazy_doctor() {
  local strict=0 quiet=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --strict)   strict=1; shift ;;
      -q|--quiet) quiet=1; shift ;;
      -h|--help)
        echo "usage: claude-kit lazy doctor [--strict] [--quiet]"
        echo "  --strict  treat warnings as failures"
        echo "  --quiet   only print problems + summary"
        return 0 ;;
      *) die "lazy doctor: unknown flag $1" ;;
    esac
  done

  local CHECKS=0 WARNS=0 FAILS=0
  _d_ok()   { CHECKS=$((CHECKS + 1)); [ "$quiet" = 1 ] || printf '  [ok]   %s\n' "$1"; }
  _d_warn() { CHECKS=$((CHECKS + 1)); WARNS=$((WARNS + 1));  printf '  [WARN] %s\n' "$1"; }
  _d_fail() { CHECKS=$((CHECKS + 1)); FAILS=$((FAILS + 1));  printf '  [FAIL] %s\n' "$1"; }

  echo "claude-kit lazy doctor:"

  # ---- global: lazy dir ---------------------------------------------------
  if [ ! -d "$LAZY_DIR" ]; then
    _d_fail "$LAZY_DIR does not exist"
    echo "----"; echo "checks=$CHECKS  warnings=$WARNS  failures=$FAILS"; echo "FAIL"
    return 1
  fi
  _d_ok "lazy dir: $LAZY_DIR"

  # ---- global: lazy.json --------------------------------------------------
  if [ -f "$LAZY_DIR/lazy.json" ]; then
    if jq -e '.' "$LAZY_DIR/lazy.json" >/dev/null 2>&1; then
      _d_ok "lazy.json valid"
      # Every described catalog must be a real sub-catalog.
      local dc
      while IFS= read -r dc; do
        [ -n "$dc" ] || continue
        if [ ! -f "$LAZY_DIR/$dc/catalog.json" ]; then
          _d_warn "lazy.json describes '$dc' but no $dc/catalog.json exists"
        fi
      done < <(jq -r '(.catalogs // {}) | keys[]' "$LAZY_DIR/lazy.json" 2>/dev/null)
    else
      _d_fail "lazy.json invalid JSON"
    fi
  else
    _d_warn "missing lazy.json (catalog descriptions)"
  fi

  # ---- global: orphan dirs (a sub-dir with no catalog.json) ---------------
  local sub
  while IFS= read -r sub; do
    [ -n "$sub" ] || continue
    local base; base=$(basename "$sub")
    case "$base" in .*) continue ;; esac   # skip dotdirs
    if [ ! -f "$sub/catalog.json" ]; then
      _d_warn "$base/ has no catalog.json (not a catalog — run 'lazy refresh $base' or remove it)"
    fi
  done < <(find "$LAZY_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)

  # _catalog_reaches_self <start> — DFS over `inherit[].from` edges; returns
  # 0 if <start> is reachable from itself (i.e. sits in a cycle).
  _catalog_reaches_self() {
    local start="$1"
    local -A onpath
    _dfs() {
      local node="$1" f
      while IFS= read -r f; do
        [ -n "$f" ] || continue
        [ "$f" = "$start" ] && return 0
        if [ -z "${onpath[$f]:-}" ] && [ -f "$LAZY_DIR/$f/catalog.json" ]; then
          onpath[$f]=1
          _dfs "$f" && return 0
        fi
      done < <(jq -r '(.inherit // [])[].from // empty' "$LAZY_DIR/$node/catalog.json" 2>/dev/null)
      return 1
    }
    _dfs "$start"
  }

  # ---- per-catalog checks -------------------------------------------------
  local c
  for c in $(_lazy_catalogs); do
    local f="$LAZY_DIR/$c/catalog.json"

    # 1) well-formed JSON (skip the rest of this catalog if not)
    if ! jq -e '.' "$f" >/dev/null 2>&1; then
      _d_fail "$c/catalog.json invalid JSON"
      continue
    fi
    _d_ok "$c/catalog.json valid"

    # 2) top-level shape: skills/agents/commands/plugins/inherit must be
    #    arrays when present.
    local badshape="" k
    for k in skills agents commands plugins inherit; do
      if jq -e --arg k "$k" 'has($k) and ((.[$k]) | type != "array")' "$f" >/dev/null 2>&1; then
        badshape="$badshape $k"
      fi
    done
    if [ -n "$badshape" ]; then
      _d_fail "$c: these top-level keys are not arrays:$badshape"
      continue
    fi

    # 3) per-entry integrity for each type.
    local t
    for t in skills agents commands plugins; do
      local -A seen_names=()
      local idx type name path
      # Field separator is \x1f (unit separator), NOT tab: tab is an IFS
      # whitespace char, so `read` would collapse an empty middle field (an
      # entry with an empty "name") and shift every later column left.
      while IFS=$'\x1f' read -r idx type name path; do
        [ -n "$idx" ] || continue
        if [ "$type" != object ]; then
          _d_fail "$c/${t}[$idx] is a $type, expected an object {name,path}"
          continue
        fi
        if [ -z "$name" ]; then
          _d_fail "$c/${t}[$idx] missing 'name'"
          continue
        fi
        if [ -n "${seen_names[$name]:-}" ]; then
          _d_warn "$c/$t: duplicate name '$name' (resolution keeps the first)"
        fi
        seen_names[$name]=1

        # plugins are registry-less: no path to validate.
        [ "$t" = plugins ] && continue

        if [ -z "$path" ]; then
          _d_fail "$c/$t/$name missing 'path'"
          continue
        fi
        if [ ! -e "$path" ]; then
          _d_fail "$c/$t/$name: dead path (does not exist): $path"
          continue
        fi
        # kind sanity: skills = dir w/ SKILL.md; agents/commands = *.md file.
        case "$t" in
          skills)
            if [ ! -d "$path" ]; then
              _d_fail "$c/skills/$name: path is not a directory: $path"
            elif [ ! -f "$path/SKILL.md" ]; then
              _d_warn "$c/skills/$name: no SKILL.md under $path"
            fi
            ;;
          agents|commands)
            if [ -d "$path" ]; then
              _d_fail "$c/$t/$name: path is a directory, expected a .md file: $path"
            elif [ ! -f "$path" ]; then
              _d_fail "$c/$t/$name: path is not a regular file: $path"
            elif [ "${path##*.}" != md ]; then
              _d_warn "$c/$t/$name: path does not end in .md: $path"
            fi
            ;;
        esac
      done < <(jq -r --arg t "$t" '
        (.[$t] // []) | to_entries[]
        | [ (.key|tostring), (.value|type), (.value.name? // ""), (.value.path? // "") ]
        | join("")' "$f" 2>/dev/null)
    done

    # 4) empty catalog (nothing to resolve, and not a virtual/inherit catalog)
    if jq -e '(((.skills//[])+(.agents//[])+(.commands//[])+(.plugins//[]))|length)==0
              and (((.inherit//[])|length)==0)' "$f" >/dev/null 2>&1; then
      _d_warn "$c: empty catalog (no entries and no inherit — run 'lazy refresh $c')"
    fi

    # 5) inherit wiring
    local i n; n=$(jq -r '(.inherit // []) | length' "$f" 2>/dev/null || echo 0)
    for ((i = 0; i < n; i++)); do
      local from; from=$(jq -r --argjson i "$i" '.inherit[$i].from // empty' "$f" 2>/dev/null)
      if [ -z "$from" ]; then
        _d_fail "$c: inherit[$i] has no 'from'"
        continue
      fi
      if [ "$from" = "$c" ]; then
        _d_fail "$c inherits from itself"
        continue
      fi
      if [ ! -f "$LAZY_DIR/$from/catalog.json" ]; then
        _d_fail "$c inherits from missing catalog: $from"
        continue
      fi
      # include/exclude names must exist in the source's EFFECTIVE set.
      local srcjson; srcjson=$(_lazy_catalog_json "$from")
      local sel; sel=$(jq -c --argjson i "$i" '.inherit[$i]' "$f")
      local bucket kind
      for kind in include exclude; do
        for bucket in skills agents commands plugins; do
          local missing; missing=$(jq -rn \
            --argjson src "$srcjson" --argjson sel "$sel" \
            --arg kind "$kind" --arg b "$bucket" '
            (($sel[$kind] // {})[$b] // []) as $want
            | (($src[$b] // []) | map(.name)) as $have
            | ($want - $have) | join(", ")' 2>/dev/null)
          if [ -n "$missing" ]; then
            _d_warn "$c: inherit '$from' $kind.$bucket names not in $from: $missing"
          fi
        done
      done
    done

    # 6) cycle detection (non-fatal — resolution is cycle-safe)
    if _catalog_reaches_self "$c"; then
      _d_warn "$c is part of an inherit cycle (resolved safely: back-edge cut, own entries only)"
    fi
  done

  # ---- summary ------------------------------------------------------------
  echo "----"
  echo "checks=$CHECKS  warnings=$WARNS  failures=$FAILS"
  if [ "$FAILS" -gt 0 ]; then
    echo "FAIL"; return 1
  fi
  if [ "$strict" = 1 ] && [ "$WARNS" -gt 0 ]; then
    echo "FAIL (--strict: warnings count as failures)"; return 1
  fi
  echo "OK"
  return 0
}
