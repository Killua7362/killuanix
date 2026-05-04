# shellcheck shell=bash
# _run_hook: dispatch a lifecycle event to the project's shared hook,
# then to the host-overlay hook (which must be SHA-trusted via
# `den hooks trust <event>`). Returns:
#   0   no hook ran, or every executed hook returned 0
#   N   the failing hook's exit code (last one to fail wins)
#   77  host hook present but content-hash didn't match trusted SHA
#       (separately surfaced so callers can short-circuit if needed)
_run_hook() { # _run_hook <project-dir> <bound-root> <event>
  local pd="$1" root="$2" event="$3"
  local rc=0
  export DEN_PROJECT_ROOT="$root" DEN_HOST="$DEN_HOST" \
    DEN_PROJECT="$(basename "$pd")" DEN_HOOK_EVENT="$event"

  # 1. Shared hook (project-side, committed in Notes).
  local shared="$pd/hooks/$event"
  if [ -f "$shared" ] && [ -x "$shared" ]; then
    if ! "$shared"; then
      rc=$?
      _warn "shared hook '$event' exited $rc"
    fi
  fi

  # 2. Host-overlay hook — SHA-trusted on this host.
  local proj
  proj="$(basename "$pd")"
  local host_hook="$DEN_OVERLAY_ROOT/$proj/hooks/$event"
  if [ -f "$host_hook" ]; then
    local trusted actual
    trusted="$(jq -r --arg n "$event" \
      '.trusted_hooks[$n] // ""' \
      "$(_meta_path "$root")" 2>/dev/null || echo "")"
    actual="$(sha256sum "$host_hook" | awk '{print $1}')"
    if [ -z "$trusted" ]; then
      _warn "host hook '$event' present but never trusted on $DEN_HOST" \
        "run: den hooks trust $event"
      rc=77
    elif [ "$trusted" != "$actual" ]; then
      _warn "host hook '$event' content changed since last trust:" \
        "trusted=${trusted:0:12}… actual=${actual:0:12}… (run: den hooks trust $event)"
      rc=77
    elif [ ! -x "$host_hook" ]; then
      _warn "host hook '$event' is not executable; skipping"
    else
      if ! "$host_hook"; then
        rc=$?
        _warn "host hook '$event' exited $rc"
      fi
    fi
  fi

  unset DEN_HOOK_EVENT
  return "$rc"
}
