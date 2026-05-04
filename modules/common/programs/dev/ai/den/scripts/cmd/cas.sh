# shellcheck shell=bash
den_cmd_cas() {
  local sub="${1:-verify}"; shift || true
  _cas_init
  case "$sub" in
    verify)
      local total=0 bad=0
      if [ -d "$DEN_CAS_ROOT/objects" ]; then
        while IFS= read -r -d $'\0' obj; do
          total=$((total + 1))
          local rel="${obj#"$DEN_CAS_ROOT/objects/"}"
          local expected="${rel/\//}"
          local actual
          actual="$(sha256sum "$obj" | awk '{print $1}')"
          if [ "$expected" != "$actual" ]; then
            printf '  [I4] hash mismatch: %s (filename) vs %s (content)\n' \
              "$expected" "$actual"
            bad=$((bad + 1))
          fi
        done < <(find "$DEN_CAS_ROOT/objects" -type f -print0)
      fi
      local refs=0
      [ -d "$DEN_CAS_ROOT/refs" ] && refs="$(find "$DEN_CAS_ROOT/refs" -type f -name '*.ref' | wc -l)"
      echo "CAS at $DEN_CAS_ROOT"
      echo "  objects: $total ($bad bad)"
      echo "  refs:    $refs"
      return "$bad"
      ;;
    show)
      local sha="${1:-}"
      [ -n "$sha" ] || _err 2 "usage: den cas show <sha>"
      local p
      p="$(_cas_path_for "$sha")"
      [ -f "$p" ] || _err 2 "no such object: $sha"
      cat "$p"
      ;;
    ls|list)
      if [ -d "$DEN_CAS_ROOT/refs" ]; then
        find "$DEN_CAS_ROOT/refs" -type f -name '*.ref' \
          | while IFS= read -r r; do
              printf '%-24s → %s\n' \
                "${r#"$DEN_CAS_ROOT/refs/"}" "$(cat "$r")"
            done
      fi
      ;;
    anchors)
      # Quick visibility into what's available for `apply --3way`.
      if [ -d "$DEN_CAS_ROOT/refs/anchors" ]; then
        for r in "$DEN_CAS_ROOT/refs/anchors"/*.ref; do
          [ -f "$r" ] || continue
          local git_sha cas_sha
          git_sha="$(basename "$r" .ref)"
          cas_sha="$(cat "$r")"
          printf '%s -> %s%s\n' "$git_sha" "$cas_sha" \
            "$([ -f "$(_cas_path_for "$cas_sha")" ] && echo "" || echo " (MISSING)")"
        done
      fi
      ;;
    *)
      _err 2 "cas: unknown subcommand $sub (try verify|show|ls|anchors)"
      ;;
  esac
}
