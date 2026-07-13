# shellcheck shell=bash
# Per-project shelf — a git-stash-like stack of den-file sets.
#
# `den shelf add` REMOVES the matched den files from the live tree (drops the
# symlink + leak guard, moves the project truth `files/<rel>` into a shelf row)
# — like `git stash`. Each `add` invocation is one ROW, stored under
# `<project>/archive/<ns>/` (ns = nanosecond epoch → sortable + unique) with a
# `manifest.json` ({name, created_at, host, files:[{rel,kind}]}). Rows travel
# with the project via the Notes vault (version-controlled).
#
#   den shelf list        rows newest-first, ids like `git stash` (0 = newest)
#   den shelf apply [id]   COPY the row's files back to their sites (row kept)
#   den shelf pop   [id]   MOVE them back and prune (row deleted when empty)
#   den shelf drop  <id>   delete one row
#   den shelf clear        wipe the whole archive (gated on Notes-clean; -f)
#
# apply/pop skip any file whose target site is occupied and report it as a
# conflict — free it (shelf it), then re-apply/pop to pick up the rest.

_shelf_dir() { printf '%s/archive\n' "$1"; }   # arg = project dir (pd)

# _shelf_rows: emit rows newest-first, one per line:
#   <id>\t<rowdir>\t<name>\t<created_at>\t<nfiles>
_shelf_rows() { # <pd>
  local pd="$1" sd; sd="$(_shelf_dir "$pd")"
  [ -d "$sd" ] || return 0
  local d id=0 mf name created n
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    mf="$d/manifest.json"; [ -f "$mf" ] || continue
    name="$(jq -r '.name // "?"' "$mf" 2>/dev/null)"
    created="$(jq -r '.created_at // "?"' "$mf" 2>/dev/null)"
    n="$(jq -r '.files | length' "$mf" 2>/dev/null)"
    printf '%d\t%s\t%s\t%s\t%s\n' "$id" "$d" "$name" "$created" "$n"
    id=$((id + 1))
  done < <(find "$sd" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -r)
}

# _shelf_row_dir_for_id: resolve an id (default 0) to its row dir; rc 1 if none.
_shelf_row_dir_for_id() { # <pd> <id>
  local pd="$1" want="${2:-0}" dir
  dir="$(_shelf_rows "$pd" | awk -F'\t' -v i="$want" '$1==i{print $2; exit}')"
  [ -n "$dir" ] || return 1
  printf '%s\n' "$dir"
}

# _shelf_resolve_targets: map path args (files, dirs, or `.`) to the set of
# den-managed rels (from the .symlinks ledger) at-or-under them. A directory
# arg (incl. `.`) expands to every ledger target under it; a file arg matches
# only if it is itself a ledger target. Dedup + sorted.
_shelf_resolve_targets() { # <root> <arg...>
  local root="$1"; shift
  local mp all; mp="$(_meta_path "$root")"
  all="$(jq -r '.symlinks[]?.target' "$mp" 2>/dev/null)"
  [ -n "$all" ] || return 0
  local p abs rel
  for p in "$@"; do
    if [ -d "$p" ]; then
      abs="$(cd "$p" 2>/dev/null && pwd -P)" || { _warn "skip $p (cannot resolve)"; continue; }
    else
      local d; d="$(cd "$(dirname -- "$p")" 2>/dev/null && pwd -P)" || { _warn "skip $p (cannot resolve)"; continue; }
      abs="$d/$(basename -- "$p")"
    fi
    case "$abs" in
      "$root") rel="";;
      "$root"/*) rel="${abs#"$root"/}";;
      *) _warn "skip $p (outside project root)"; continue;;
    esac
    if [ -d "$abs" ] || [ -z "$rel" ]; then
      if [ -z "$rel" ]; then printf '%s\n' "$all"
      else printf '%s\n' "$all" | awk -v pre="$rel/" 'index($0,pre)==1'; fi
    else
      printf '%s\n' "$all" | grep -qxF -- "$rel" && printf '%s\n' "$rel"
    fi
  done | awk 'NF' | sort -u
}

# _shelf_add: build a new row from resolved rels, removing each from the live
# tree (git-stash semantics). Skips rels not actually present/managed.
_shelf_add() { # <root> <pd> <name> <rel...>
  local root="$1" pd="$2" name="$3"; shift 3
  [ "$#" -gt 0 ] || { _warn "no den-managed files matched; nothing shelved"; return 0; }
  local sd ns rowdir created files_json rel kind srcp site
  sd="$(_shelf_dir "$pd")"; mkdir -p "$sd"
  ns="$(date +%s%N)"; rowdir="$sd/$ns"; mkdir -p "$rowdir/files"
  created="$(date -Iseconds)"; files_json="[]"
  for rel in "$@"; do
    site="$root/$rel"
    if [ ! -L "$site" ] && [ ! -e "$site" ]; then _warn "$rel: not present at site; skipping"; continue; fi
    srcp="$pd/files/$rel"
    if [ ! -e "$srcp" ]; then _warn "$rel: project content missing; skipping"; continue; fi
    kind="$(_kind_for_rel "$pd" "$rel")"; [ -n "$kind" ] || kind=symlink
    mkdir -p "$rowdir/files/$(dirname -- "$rel")"
    mv -f "$srcp" "$rowdir/files/$rel"          # move the truth into the row
    _guard_unlink "$root" "$rel"                # drop the leak guard (no-op off-repo)
    rm -f "$site"                               # drop the site symlink/hardlink name
    _set_manifest_kind "$pd" "$rel" symlink     # clear any kind override
    _meta_update "$root" '.symlinks |= map(select(.target != $t))' --arg t "$rel"
    files_json="$(printf '%s' "$files_json" | jq --arg r "$rel" --arg k "$kind" '. + [{rel:$r,kind:$k}]')"
    echo "  shelved $rel"
  done
  local n; n="$(printf '%s' "$files_json" | jq 'length')"
  if [ "$n" = 0 ]; then rm -rf "$rowdir"; _warn "nothing shelved"; return 0; fi
  jq -n --arg name "$name" --arg created "$created" --arg host "$DEN_HOST" --argjson files "$files_json" \
    '{name:$name, created_at:$created, host:$host, files:$files}' >"$rowdir/manifest.json"
  _info "shelved $n file(s) as '$name'"
}

# _shelf_materialize: restore one file to its site. rc 0 = done, 2 = conflict
# (site occupied), 3 = archived content missing. mode=copy (apply) | move (pop).
_shelf_materialize() { # <root> <pd> <rowdir> <rel> <kind> <copy|move>
  local root="$1" pd="$2" rowdir="$3" rel="$4" kind="$5" mode="$6"
  local site="$root/$rel" arch="$rowdir/files/$rel" truth="$pd/files/$rel"
  { [ -e "$site" ] || [ -L "$site" ]; } && return 2      # occupied → conflict
  [ -e "$arch" ] || { _warn "$rel: archived content missing"; return 3; }
  mkdir -p "$(dirname -- "$truth")" "$(dirname -- "$site")"
  if [ "$mode" = move ]; then mv -f "$arch" "$truth"; else cp -a "$arch" "$truth"; fi
  _link_for_kind "$kind" "$truth" "$site"
  _guard_after_link "$root" "$pd" "$rel"
  [ "$kind" = symlink ] || _set_manifest_kind "$pd" "$rel" "$kind"
  _meta_update "$root" \
    '.symlinks |= (map(select(.target != $t)) + [{src:$s, target:$t, mode:"0644", kind:$k}])' \
    --arg t "$rel" --arg s "files/$rel" --arg k "$kind"
  return 0
}

# _shelf_apply: apply (copy, row kept) or pop (move, row removed) one row —
# ALL-OR-NOTHING. A pre-flight scan checks every file first; if ANY target site
# is occupied (conflict) or its archived content is missing, nothing is touched
# and the offending paths are listed. Only a fully-clean row is materialized.
_shelf_apply() { # <root> <pd> <id> <apply|pop>
  local root="$1" pd="$2" id="${3:-0}" verb="$4"
  local rowdir mf mode rel kind
  rowdir="$(_shelf_row_dir_for_id "$pd" "$id")" || _err 2 "no shelf row with id $id (den shelf list)"
  mf="$rowdir/manifest.json"
  [ "$verb" = pop ] && mode=move || mode=copy

  # Pre-flight (touches nothing).
  local -a conflicts=() missing=()
  local site arch
  while IFS=$'\t' read -r rel kind; do
    [ -n "$rel" ] || continue
    site="$root/$rel"; arch="$rowdir/files/$rel"
    { [ -e "$site" ] || [ -L "$site" ]; } && conflicts+=("$rel")
    [ -e "$arch" ] || missing+=("$rel")
  done < <(jq -r '.files[]? | [.rel, .kind] | @tsv' "$mf")

  if [ "${#conflicts[@]}" -gt 0 ] || [ "${#missing[@]}" -gt 0 ]; then
    if [ "${#conflicts[@]}" -gt 0 ]; then
      _warn "$verb aborted — target path(s) already occupied (nothing changed):"
      printf '    %s\n' "${conflicts[@]}" >&2
    fi
    if [ "${#missing[@]}" -gt 0 ]; then
      _warn "$verb aborted — archived content missing (nothing changed):"
      printf '    %s\n' "${missing[@]}" >&2
    fi
    return 1
  fi

  # Clean row — materialize every file.
  local applied=0 rc
  while IFS=$'\t' read -r rel kind; do
    [ -n "$rel" ] || continue
    [ -n "$kind" ] || kind=symlink
    _shelf_materialize "$root" "$pd" "$rowdir" "$rel" "$kind" "$mode"; rc=$?
    if [ "$rc" -eq 0 ]; then applied=$((applied + 1)); else _warn "$rel: unexpected failure (rc=$rc)"; fi
  done < <(jq -r '.files[]? | [.rel, .kind] | @tsv' "$mf")

  if [ "$verb" = pop ]; then
    rm -rf "$rowdir"
    _info "pop: $applied file(s) moved from row $id (row removed)"
  else
    _info "apply: $applied file(s) copied from row $id (row kept)"
  fi
  return 0
}

_shelf_drop() { # <pd> <id>
  local pd="$1" id="$2" rowdir
  rowdir="$(_shelf_row_dir_for_id "$pd" "$id")" || _err 2 "no shelf row with id $id"
  rm -rf "$rowdir"
  _info "dropped shelf row $id"
}

_shelf_clear() { # <pd> <force 0|1>
  local pd="$1" force="$2" sd; sd="$(_shelf_dir "$pd")"
  [ -d "$sd" ] || { _info "shelf already empty"; return 0; }
  if [ "$force" != 1 ] && ! _notes_path_committed "$sd"; then
    _err 2 "shelf archive has uncommitted changes in Notes — commit + push, or use -f" \
      "checked: $sd"
  fi
  rm -rf "$sd"
  _info "cleared shelf"
}

_shelf_list() { # <pd>
  local pd="$1" rows
  rows="$(_shelf_rows "$pd")"
  if [ -z "$rows" ]; then echo "(no shelved rows)"; return 0; fi
  {
    printf 'ID\tNAME\tCREATED\tFILES\n'
    printf '%s\n' "$rows" | awk -F'\t' '{printf "%s\t%s\t%s\t%s\n", $1, $3, $4, $5}'
  } | column -t -s "$(printf '\t')" | { if [ -t 1 ]; then ${PAGER:-less -R}; else cat; fi; }
}
