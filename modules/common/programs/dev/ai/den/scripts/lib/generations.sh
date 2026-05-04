# shellcheck shell=bash
# Per-cwd snapshot generations under <root>/.den-generations/.
_gen_dir() { printf '%s/.den-generations\n' "$1"; }

_write_generation() { # _write_generation <root> <op>
  local root="$1" op="$2"
  local gd
  gd="$(_gen_dir "$root")"
  mkdir -p "$gd"
  local n=1
  if [ -f "$gd/HEAD" ]; then
    n=$(($(cat "$gd/HEAD") + 1))
  fi
  local meta
  meta="$(_meta_path "$root")"
  local notes_sha
  notes_sha="$(git -C "$DEN_NOTES" rev-parse HEAD 2>/dev/null || echo "")"
  jq --arg op "$op" --arg ts "$(date -Iseconds)" --arg notes "$notes_sha" --argjson n "$n" \
    '{generation:$n, ts:$ts, op:$op, notes_commit_sha:$notes,
      manifest_hash:.manifest_hash, symlinks:.symlinks, host_only:.host_only,
      lastop:.lastop}' \
    "$meta" > "$gd/gen-$(printf '%03d' "$n").json"
  echo "$n" >"$gd/HEAD"
}
