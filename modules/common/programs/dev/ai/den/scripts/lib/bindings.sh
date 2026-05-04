# shellcheck shell=bash
# Per-host bindings registry — maps project → array of bound cwds on this host.
# File: $DEN_BINDINGS. Used by `den cd`, `den which`, and `den last-applied`.

_bindings_init() {
  mkdir -p "$(dirname "$DEN_BINDINGS")"
  [ -f "$DEN_BINDINGS" ] || echo '{}' >"$DEN_BINDINGS"
}

_bindings_add() { # _bindings_add <project> <cwd>
  _bindings_init
  local tmp
  tmp="$(mktemp)"
  jq --arg p "$1" --arg c "$2" \
    '.[$p] = ((.[$p] // []) + [$c] | unique)' \
    "$DEN_BINDINGS" >"$tmp" && mv "$tmp" "$DEN_BINDINGS"
}

_bindings_remove() { # _bindings_remove <project> <cwd>
  _bindings_init
  local tmp
  tmp="$(mktemp)"
  jq --arg p "$1" --arg c "$2" \
    '.[$p] = ((.[$p] // []) | map(select(. != $c)))
     | if (.[$p] | length) == 0 then del(.[$p]) else . end' \
    "$DEN_BINDINGS" >"$tmp" && mv "$tmp" "$DEN_BINDINGS"
}

_bindings_list_for() { # _bindings_list_for <project>  → cwds, one per line
  _bindings_init
  jq -r --arg p "$1" '.[$p] // [] | .[]' "$DEN_BINDINGS"
}

# _bindings_owner: given an absolute path, return the project whose
# bound cwd is the longest prefix of it (or empty + nonzero on miss).
_bindings_owner() { # _bindings_owner <abs-path>  → project<TAB>cwd
  _bindings_init
  local target="$1"
  # Iterate every project's cwds; pick longest match.
  jq -r 'to_entries[] | .key as $p | .value[] | "\($p)\t\(.)"' \
    "$DEN_BINDINGS" \
    | awk -v t="$target" '
        BEGIN { best_len = -1 }
        {
          cwd = $2
          pl  = length(cwd)
          if (substr(t, 1, pl) == cwd && (pl == length(t) || substr(t, pl+1, 1) == "/")) {
            if (pl > best_len) { best_len = pl; best = $0 }
          }
        }
        END { if (best_len >= 0) print best }
      '
}

# Sanity-prune: drop registry entries whose .den-meta.json no longer
# exists or no longer points at the same project.
_bindings_prune() {
  _bindings_init
  local tmp
  tmp="$(mktemp)"
  local cleaned="{}"
  while IFS=$'\t' read -r proj cwd; do
    [ -z "$proj" ] && continue
    if [ -f "$cwd/.den-meta.json" ]; then
      local actual
      actual="$(jq -r '.project // ""' "$cwd/.den-meta.json" 2>/dev/null || true)"
      if [ "$actual" = "$proj" ]; then
        cleaned="$(jq --arg p "$proj" --arg c "$cwd" \
          '.[$p] = ((.[$p] // []) + [$c] | unique)' <<<"$cleaned")"
      fi
    fi
  done < <(jq -r 'to_entries[] | .key as $p | .value[] | "\($p)\t\(.)"' "$DEN_BINDINGS")
  echo "$cleaned" >"$tmp" && mv "$tmp" "$DEN_BINDINGS"
}
