# shellcheck shell=bash
den_cmd_pull() {
  local dry=0 ignore_failures=0 resume=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run|-n) dry=1; shift;;
      --ignore-failures) ignore_failures=1; shift;;
      --resume) resume=1; shift;;
      *) shift;;
    esac
  done
  _bind_ctx
  local root="$BOUND_ROOT" proj="$BOUND_PROJECT"

  if [ "$dry" = 1 ]; then
    _do_pull_dry "$root" "$proj"
  else
    _with_lock "$root" _do_pull "$root" "$proj" "$ignore_failures" "$resume"
  fi
}

_do_pull_dry() {
  local root="$1" proj="$2"
  local pd
  pd="$(_project_dir_for "$proj")"
  local data
  data="$("$DEN_HELPER_BIN" status --cwd "$root" --project-dir "$pd")"
  echo "$data" | "$DEN_HELPER_BIN" render-status
  echo
  echo "dry-run: would create the following links:"
  echo "$data" | jq -r '.["missing-link"][] | "  + " + .'
}

_do_pull() {
  local root="$1" proj="$2" ignore_failures="${3:-0}" resume="${4:-0}"
  local pd
  pd="$(_project_dir_for "$proj")"
  [ -d "$pd" ] || _err 2 "project source missing: $pd"

  # Run shared pre-pull, then host pre-pull
  _run_hook "$pd" "$root" pre-pull || true

  local data
  data="$("$DEN_HELPER_BIN" status --cwd "$root" --project-dir "$pd")"
  local drift
  drift="$(echo "$data" | jq -r .drift_count)"

  # Cache kind lookups for the duration of the pull.
  local kinds
  kinds="$(_load_manifest_kinds "$pd")"

  # Build new links for missing-link entries.
  local errors=0
  local applied=0
  local missing_clones=0
  while IFS= read -r rel; do
    [ -z "$rel" ] && continue
    local src="$pd/files/$rel"
    local target="$root/$rel"
    # Clone gate: if this file belongs inside a registered clone that isn't
    # present yet, skip it (don't create the clone's dirs) and report the
    # `git clone` to run. Root-scaffolding files (no clone) fall through.
    local cp
    cp="$(_clone_path_for_rel "$pd" "$rel")"
    if [ -n "$cp" ] && [ ! -e "$root/$cp/.git" ]; then
      local rmt; rmt="$(_clone_remote_for_path "$pd" "$cp")"
      _warn "clone '$cp' not present — clone it, then re-run den pull:"
      printf '    git clone %s %s\n' "${rmt:-<remote-unknown>}" "$root/$cp" >&2
      missing_clones=$((missing_clones+1))
      continue
    fi
    mkdir -p "$(dirname "$target")"
    # validate source exists
    if [ ! -e "$src" ]; then
      _warn "source missing for $rel; skipping"
      errors=$((errors+1))
      continue
    fi
    local kind
    kind="$(echo "$kinds" | jq -r --arg r "$rel" '.[$r] // "symlink"')"
    if ! _link_for_kind "$kind" "$src" "$target" 2>/dev/null; then
      _warn "failed to $kind $rel"
      errors=$((errors+1))
      [ "$ignore_failures" -eq 1 ] || break
    else
      applied=$((applied+1))
    fi
  done < <(echo "$data" | jq -r '.["missing-link"][]')

  # Update symlinks ledger from current state. The ledger key stays
  # `.symlinks` for backwards compat, but each entry now carries a
  # `kind` field so clean/restore can branch correctly.
  local sym_arr="[]"
  for rel in $(echo "$data" | jq -r '.["missing-link"][]'; echo "$data" | jq -r '.ok[]?'); do
    [ -z "$rel" ] && continue
    local kind
    kind="$(echo "$kinds" | jq -r --arg r "$rel" '.[$r] // "symlink"')"
    sym_arr="$(echo "$sym_arr" | jq --arg t "$rel" --arg s "files/$rel" --arg k "$kind" \
      '. + [{src: $s, target: $t, mode: "0644", kind: $k}]')"
    # Reassert the leak guard for every present link (idempotent; no-op when
    # the site isn't inside a git tree, e.g. a clone still missing).
    _guard_after_link "$root" "$pd" "$rel"
  done
  local mh
  mh="$("$DEN_HELPER_BIN" manifest-hash --root "$pd" | jq -r .hash)"
  _meta_update "$root" \
    '.symlinks = $arr | .manifest_hash = $mh' \
    --argjson arr "$sym_arr" --arg mh "$mh"

  local new_drift
  new_drift="$("$DEN_HELPER_BIN" status --cwd "$root" --project-dir "$pd" | jq -r .drift_count)"
  _record_lastop "$root" pull "$errors" "$new_drift"
  _record_activity "$proj" pull "$errors" "$new_drift"
  _bindings_add "$proj" "$root"
  _maybe_zoxide_add "$root"
  _write_generation "$root" pull

  _run_hook "$pd" "$root" post-pull || true

  if [ "$errors" -gt 0 ] && [ "$ignore_failures" -ne 1 ]; then
    _err 1 "pull failed ($errors error(s)); $applied link(s) applied"
  fi
  echo "applied $applied link(s); drift after = $new_drift"
  if [ "$missing_clones" -gt 0 ]; then
    echo "note: $missing_clones clone(s) not present — clone them (commands above), then re-run den pull"
  fi
}
