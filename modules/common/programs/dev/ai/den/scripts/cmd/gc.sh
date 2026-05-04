# shellcheck shell=bash
den_cmd_gc() {
  local dry=0 rebuild=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run|-n) dry=1; shift;;
      --rebuild) rebuild=1; shift;;
      *) shift;;
    esac
  done

  # 1. Generations: keep last 20 per cwd; only run if we're bound.
  local out
  out="$(_require_bound)" 2>/dev/null || true
  if [ -n "$out" ]; then
    local root
    root="$(echo "$out" | sed -n 1p)"
    local gd
    gd="$(_gen_dir "$root")"
    if [ -d "$gd" ]; then
      local cur
      cur="$(cat "$gd/HEAD" 2>/dev/null || echo 0)"
      local keep_after=$((cur - 20))
      for f in "$gd"/gen-*.json; do
        [ -f "$f" ] || continue
        local g
        g="$(basename "$f" .json | sed 's/gen-//' | sed 's/^0*//')"
        [ -z "$g" ] && g=0
        if [ "$g" -lt "$keep_after" ]; then
          if [ "$dry" = 1 ]; then echo "would prune: $f"
          else rm -f "$f"; echo "pruned: $f"; fi
        fi
      done
    fi
  fi

  # 2. CAS rebuild — drop all caches, refs survive (we re-cache on next apply).
  if [ "$rebuild" = 1 ]; then
    rm -rf "$DEN_CAS_ROOT"
    _cas_init
    echo "rebuilt empty CAS at $DEN_CAS_ROOT"
    return 0
  fi

  # 3. CAS GC: walk refs/ → live set; delete loose objects older than
  # gc.cas.unrefExpire (default 14 days) not in the live set.
  _cas_init
  local live_set
  live_set="$(mktemp)"
  # collect all SHAs that any ref points at
  if [ -d "$DEN_CAS_ROOT/refs" ]; then
    find "$DEN_CAS_ROOT/refs" -type f -name '*.ref' -print0 \
      | xargs -0 -r cat 2>/dev/null \
      | sort -u >"$live_set"
  else
    : >"$live_set"
  fi

  local cutoff_secs
  cutoff_secs="$(date -d '14 days ago' +%s 2>/dev/null || date +%s)"

  local pruned=0 kept=0
  if [ -d "$DEN_CAS_ROOT/objects" ]; then
    while IFS= read -r -d $'\0' obj; do
      local rel="${obj#"$DEN_CAS_ROOT/objects/"}"
      local sha="${rel/\//}"
      if grep -qxF "$sha" "$live_set"; then
        kept=$((kept + 1))
        continue
      fi
      local mtime
      mtime="$(stat -c %Y "$obj" 2>/dev/null || echo 0)"
      if [ "$mtime" -lt "$cutoff_secs" ]; then
        if [ "$dry" = 1 ]; then echo "would prune CAS object: $sha"
        else rm -f "$obj"; pruned=$((pruned + 1)); fi
      else
        kept=$((kept + 1))
      fi
    done < <(find "$DEN_CAS_ROOT/objects" -type f -print0)
  fi
  rm -f "$live_set"

  if [ "$dry" = 1 ]; then
    echo "(dry-run) CAS: $kept kept, pruning candidates listed above"
  else
    echo "CAS: pruned $pruned, kept $kept"
  fi
}
