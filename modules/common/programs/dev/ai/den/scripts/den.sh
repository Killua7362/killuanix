# shellcheck shell=bash
# den — project-scoped symlink + patch manager (entrypoint).
#
# Sources lib/*.sh and cmd/*.sh from $DEN_LIB_DIR, then dispatches based
# on $1. Globals (DEN_LIB_DIR, DEN_HELPER_BIN) come from the Nix wrapper
# in default.nix.

set -u

# ---- globals -------------------------------------------------------------
DEN_NOTES="${DEN_NOTES:-$HOME/killuanix/Notes}"
DEN_PROJECTS="$DEN_NOTES/projects"
DEN_STATE="${XDG_DATA_HOME:-$HOME/.local/share}/den"
DEN_OVERLAY_ROOT="$DEN_STATE/overlay"
DEN_CAS_ROOT="$DEN_STATE/cas"
DEN_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/den/config.toml"
DEN_HOST="${HOSTNAME:-$(hostname -s 2>/dev/null || echo unknown)}"
# Per-host bindings registry (host-only, never pushed). Maps project →
# array of cwds bound to it on this host. Powers `den cd` / `den which`.
DEN_BINDINGS="$DEN_STATE/bindings.json"

# ---- source libs + cmds --------------------------------------------------
# shellcheck disable=SC1090,SC1091
for f in "$DEN_LIB_DIR"/lib/*.sh; do
  [ -f "$f" ] && . "$f"
done
# shellcheck disable=SC1090,SC1091
for f in "$DEN_LIB_DIR"/cmd/*.sh; do
  [ -f "$f" ] && . "$f"
done

# ---- dispatch ------------------------------------------------------------
_try_external_subcommand() { # _try_external_subcommand <maybe-subcmd> <args...>
  local sub="$1"; shift
  if command -v "den-$sub" >/dev/null 2>&1; then
    exec "den-$sub" "$@"
  fi
  return 1
}

main() {
  local sub="${1:-help}"
  shift || true
  case "$sub" in
    help|-h|--help)         den_cmd_help "$@";;
    version|-V|--version)   den_cmd_version;;
    explain)                den_cmd_explain "$@";;
    new)                    den_cmd_new "$@";;
    init)                   den_cmd_init "$@";;
    list)                   den_cmd_list "$@";;
    ls)                     den_cmd_ls "$@";;
    status|st)              den_cmd_status "$@";;
    add)                    den_cmd_add "$@";;
    ignore)                 den_cmd_ignore "$@";;
    rm)                     den_cmd_rm "$@";;
    re-add)                 den_cmd_re_add "$@";;
    restore)                den_cmd_restore "$@";;
    pull)                   den_cmd_pull "$@";;
    replicate)              den_cmd_replicate "$@";;
    clean)                  den_cmd_clean "$@";;
    sync)                   den_cmd_sync "$@";;
    stash)                  den_cmd_stash "$@";;
    apply)                  den_cmd_apply "$@";;
    patches)                den_cmd_patches "$@";;
    log)                    den_cmd_log "$@";;
    last-applied)           den_cmd_last_applied "$@";;
    reflog)                 den_cmd_reflog "$@";;
    generations)            den_cmd_generations "$@";;
    rollback)               den_cmd_rollback "$@";;
    diff)                   den_cmd_diff "$@";;
    which)                  den_cmd_which "$@";;
    cd)                     den_cmd_cd "$@";;
    exec)                   den_cmd_exec "$@";;
    activate)               den_cmd_activate "$@";;
    prompt)                 den_cmd_prompt "$@";;
    gc)                     den_cmd_gc "$@";;
    cas)                    den_cmd_cas "$@";;
    config)                 den_cmd_config "$@";;
    hooks)                  den_cmd_hooks "$@";;
    doctor)                 den_cmd_doctor "$@";;
    completion)             den_cmd_completion "$@";;
    *)
      if _try_external_subcommand "$sub" "$@"; then :; fi
      _err 2 "unknown subcommand: $sub" "" "try: den help"
      ;;
  esac
}

main "$@"
