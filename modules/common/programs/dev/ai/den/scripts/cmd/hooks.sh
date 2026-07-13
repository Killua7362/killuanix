# shellcheck shell=bash
den_cmd_hooks() {
  local sub="${1:-}"
  case "$sub" in
    trust)
      shift
      local name="${1:-}"
      [ -n "$name" ] || _err 2 "usage: den hooks trust <event>"
      _bind_ctx
      local root="$BOUND_ROOT" proj="$BOUND_PROJECT"
      local hook="$DEN_OVERLAY_ROOT/$proj/hooks/$name"
      [ -f "$hook" ] || _err 2 "no host hook at $hook"
      local sha
      sha="$(sha256sum "$hook" | awk '{print $1}')"
      _meta_update "$root" \
        '.trusted_hooks[$n] = $s' \
        --arg n "$name" --arg s "$sha"
      echo "trusted host hook '$name' (sha256: ${sha:0:12}…)"
      ;;
    *) _err 2 "usage: den hooks trust <event>";;
  esac
}
