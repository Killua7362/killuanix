# shellcheck shell=bash
den_cmd_doctor() {
  local strict=0
  case "${1:-}" in --strict) strict=1;; esac
  local exit_code=0
  if ! _try_bind_ctx; then
    echo "[no binding here] (run \`den init <NAME>\`)"
    return 0
  fi
  local root="$BOUND_ROOT" proj="$BOUND_PROJECT"
  local pd
  pd="$(_project_dir_for "$proj")"

  echo "den doctor — project '$proj' at $root"
  # I1/I2: drift
  local data
  data="$("$DEN_HELPER_BIN" status --cwd "$root" --project-dir "$pd")"
  local drift
  drift="$(echo "$data" | jq -r .drift_count)"
  if [ "$drift" -gt 0 ]; then
    printf '  [DRIFT] %d items (run: den status)\n' "$drift"
    exit_code=$((exit_code + drift))
  else
    echo "  [ok] no drift"
  fi
  # I4: CAS — for v1, just check directory exists
  if [ -d "$DEN_CAS_ROOT" ] && command -v sha256sum >/dev/null; then
    echo "  [ok] CAS at $DEN_CAS_ROOT"
  else
    echo "  [info] CAS not initialized (will create on first stash)"
  fi
  # I7: dangling links
  local dangling=0
  while IFS= read -r tgt; do
    [ -L "$root/$tgt" ] || continue
    local actual
    actual="$(readlink -f "$root/$tgt" 2>/dev/null || true)"
    [ -z "$actual" ] && dangling=$((dangling+1))
  done < <(jq -r '.symlinks[].target' "$(_meta_path "$root")")
  if [ "$dangling" -gt 0 ]; then
    printf '  [DANGLING] %d link(s)\n' "$dangling"
    exit_code=$((exit_code + dangling))
  fi
  # G1: leak guard — SECURITY: an in-repo link not in info/exclude would leak
  # to that clone's remote on a stray `git add`.
  local unguarded=0 t
  while IFS= read -r t; do
    [ -L "$root/$t" ] || continue
    _guard_is_guarded "$root" "$t" || unguarded=$((unguarded+1))
  done < <(jq -r '.symlinks[].target' "$(_meta_path "$root")")
  if [ "$unguarded" -gt 0 ]; then
    printf '  [UNGUARDED] %d in-repo link(s) not in info/exclude — WOULD LEAK (run: den pull)\n' "$unguarded"
    exit_code=$((exit_code + unguarded))
  else
    echo "  [ok] in-repo links info/exclude-guarded"
  fi
  # G2: registered clones present? (missing is expected on a fresh host)
  local mc=0 cp
  while IFS= read -r cp; do
    [ -n "$cp" ] && [ "$cp" != "." ] || continue
    [ -e "$root/$cp/.git" ] || mc=$((mc+1))
  done < <(_clones_read "$pd" | jq -r '.clones[]?.path')
  if [ "$mc" -gt 0 ]; then
    if [ "$strict" = 1 ]; then
      printf '  [CLONES] %d registered clone(s) missing (run: den pull)\n' "$mc"
      exit_code=$((exit_code + mc))
    else
      printf '  [info] %d registered clone(s) not present — den pull prints git clone commands\n' "$mc"
    fi
  fi
  # I3: anchor missing — lax
  # (placeholder: check each patch has a Den-Anchor trailer)
  local missing_anchor=0
  if [ -d "$pd/patches" ]; then
    for p in "$pd"/patches/*/*.patch; do
      [ -f "$p" ] || continue
      grep -q '^Den-Anchor:' "$p" || missing_anchor=$((missing_anchor+1))
    done
  fi
  if [ "$missing_anchor" -gt 0 ]; then
    if [ "$strict" = 1 ]; then
      printf '  [I3] %d patch(es) missing Den-Anchor: trailer\n' "$missing_anchor"
      exit_code=$((exit_code + missing_anchor))
    else
      printf '  [info I3] %d patch(es) missing Den-Anchor: trailer (run `den explain I3`)\n' "$missing_anchor"
    fi
  fi
  return "$exit_code"
}
