# shellcheck shell=bash
# den bootstrap — read-only "what do I need to do to make cwd match this
# project?" It reconciles the current structure against clones.json + the file
# ledger and prints ONLY the actionable differences: `git clone`/`mkdir` for
# clones that are missing/empty, warnings for occupied/mismatched paths, and a
# `den pull` hint ONLY when there is drift pull can actually fix. If everything
# already matches it says so and prints nothing to run. Works on a scratch
# checkout AND after a drift / a new clones.json entry synced from another host.
den_cmd_bootstrap() {
  _bind_ctx
  local root="$BOUND_ROOT" proj="$BOUND_PROJECT" pd
  pd="$(_project_dir_for "$proj")"

  local -a clone_cmds=() mkdir_cmds=() diff_remote=() not_repo=()
  local n=0
  while IFS=$'\t' read -r p r; do
    [ -n "$p" ] || continue
    [ "$p" = "." ] && continue                 # binding root — already here
    n=$((n+1))
    local full="$root/$p"
    if [ ! -e "$full" ]; then
      if [ -n "$r" ]; then
        clone_cmds+=("git clone $r $full")
      else
        mkdir_cmds+=("mkdir -p $full")
      fi
    elif [ -z "$(ls -A "$full" 2>/dev/null)" ]; then
      # exists but empty → clone into it (git accepts an empty target)
      if [ -n "$r" ]; then
        clone_cmds+=("git clone $r $full")
      fi
    else
      # exists and non-empty
      if [ -e "$full/.git" ] && git -C "$full" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        local cur; cur="$(git -C "$full" remote get-url origin 2>/dev/null || true)"
        if [ -n "$r" ] && [ "$cur" != "$r" ]; then
          diff_remote+=("$p (expected $r, found ${cur:-<none>})")
        fi
        # matching remote (or no expected remote) → already good, nothing to do
      else
        not_repo+=("$p (expected ${r:-<none>})")
      fi
    fi
  done < <(_clones_read "$pd" | jq -r '.clones[]? | .path + "\t" + (.remote // "")')

  # Pullable drift: missing-link files that `den pull` could materialize *right
  # now* — i.e. root/non-clone files, or files whose owning clone is already
  # present + matching. (Files gated behind a not-yet-cloned repo don't count —
  # the clone commands above cover those.)
  local pullable=0 rel cp
  local status_json
  status_json="$("$DEN_HELPER_BIN" status --cwd "$root" --project-dir "$pd" 2>/dev/null || echo '{}')"
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    cp="$(_clone_path_for_rel "$pd" "$rel")"
    if [ -z "$cp" ] || _clone_present_ok "$root" "$pd" "$cp"; then
      pullable=1; break
    fi
  done < <(echo "$status_json" | jq -r '.["missing-link"][]?')

  # Structural commands (only printed when there's an actual difference).
  local printed=0
  if [ "${#clone_cmds[@]}" -gt 0 ]; then
    echo "# clone these repos:"
    printf '%s\n' "${clone_cmds[@]}"
    printed=1
  fi
  if [ "${#mkdir_cmds[@]}" -gt 0 ]; then
    echo "# create these paths (registered without a remote):"
    printf '%s\n' "${mkdir_cmds[@]}"
    printed=1
  fi
  if [ "${#diff_remote[@]}" -gt 0 ]; then
    echo "# these paths have a DIFFERENT remote than clones.json (left untouched):" >&2
    printf '  %s\n' "${diff_remote[@]}" >&2
    printed=1
  fi
  if [ "${#not_repo[@]}" -gt 0 ]; then
    echo "# these paths are non-empty but not a git repo (left untouched):" >&2
    printf '  %s\n' "${not_repo[@]}" >&2
    printed=1
  fi

  # Next action: pull only if there's drift pull can fix (after any clones).
  if [ "${#clone_cmds[@]}" -gt 0 ] || [ "${#mkdir_cmds[@]}" -gt 0 ]; then
    echo "# then: den pull"
  elif [ "$pullable" -eq 1 ]; then
    echo "# structure matches — but files need materializing. run: den pull"
  elif [ "$printed" -eq 0 ]; then
    echo "nothing to do — cwd matches this project."
  fi
}
