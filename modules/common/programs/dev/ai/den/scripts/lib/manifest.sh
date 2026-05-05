# shellcheck shell=bash
# manifest.toml helpers — read/write per-file `kind` overrides.
#
# Default kind is "symlink"; manifest.toml only stores entries that need
# something different. Currently supported kinds:
#   symlink  — absolute symlink from cwd into Notes/projects/<N>/files/<rel>
#   hardlink — same-filesystem hardlink (real file at both paths, sharing
#              one inode). Required for entry points that don't tolerate
#              symlinks pointing outside their tree — most notably nix
#              flakes, which copy the source to /nix/store/<hash>-source/
#              and then mis-resolve absolute symlinks relative to that
#              copy. A hardlink looks like a real file to nix while still
#              auto-syncing edits with the project copy in Notes.

# _load_manifest_kinds <project-dir>
# Returns a JSON object mapping rel → kind for every entry in
# manifest.toml that has both `src = "files/<rel>"` and a `kind`.
# Returns "{}" on missing/empty/invalid manifest.
_load_manifest_kinds() {
  local pd="$1"
  local manifest="$pd/manifest.toml"
  [ -f "$manifest" ] || { echo '{}'; return; }
  local data
  data="$("$DEN_HELPER_BIN" parse-toml --path "$manifest" 2>/dev/null)" || { echo '{}'; return; }
  echo "$data" | jq '
    (.entry // []) | map(
      select(.src and .kind and (.src | startswith("files/")))
      | {key: (.src | sub("^files/"; "")), value: .kind}
    ) | from_entries
  '
}

# _kind_for_rel <project-dir> <rel>
# Echoes the kind for a single rel, defaulting to "symlink".
_kind_for_rel() {
  local pd="$1" rel="$2"
  local k
  k="$(_load_manifest_kinds "$pd" | jq -r --arg r "$rel" '.[$r] // "symlink"')"
  [ -n "$k" ] && [ "$k" != "null" ] && echo "$k" || echo "symlink"
}

# _set_manifest_kind <project-dir> <rel> <kind>
# Inserts or updates the entry; passing kind="symlink" removes the entry
# (symlink is the default and doesn't need an override).
_set_manifest_kind() {
  local pd="$1" rel="$2" kind="$3"
  local manifest="$pd/manifest.toml"
  local data='{}'
  if [ -f "$manifest" ]; then
    data="$("$DEN_HELPER_BIN" parse-toml --path "$manifest" 2>/dev/null)" || data='{}'
  fi
  local new_data
  if [ "$kind" = "symlink" ]; then
    new_data="$(echo "$data" | jq --arg s "files/$rel" '
      .entry = ((.entry // []) | map(select(.src != $s)))
      | if ((.entry // []) | length) == 0 then del(.entry) else . end
    ')"
  else
    new_data="$(echo "$data" | jq --arg s "files/$rel" --arg k "$kind" '
      .entry = ((.entry // []) | map(select(.src != $s)) + [{src: $s, kind: $k}])
    ')"
  fi
  if [ "$(echo "$new_data" | jq 'length')" = "0" ]; then
    rm -f "$manifest"
  else
    echo "$new_data" | "$DEN_HELPER_BIN" write-toml --path "$manifest"
  fi
}

# _link_for_kind <kind> <src> <target>
# Creates the appropriate link from <target> → <src>. Replaces any
# existing target. Errors out for hardlink across filesystems.
_link_for_kind() {
  local kind="$1" src="$2" target="$3"
  case "$kind" in
    symlink)
      ln -snf "$src" "$target"
      ;;
    hardlink)
      local src_dev tgt_dev
      src_dev="$(stat -c %d "$src" 2>/dev/null || echo 0)"
      tgt_dev="$(stat -c %d "$(dirname "$target")" 2>/dev/null || echo 0)"
      if [ "$src_dev" != "$tgt_dev" ]; then
        _err 2 "cross-filesystem hardlink not possible: $src ↔ $target"
      fi
      rm -f "$target"
      ln "$src" "$target"
      ;;
    *)
      _err 2 "unknown link kind: $kind (expected symlink|hardlink)"
      ;;
  esac
}
