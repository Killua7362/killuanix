#!/usr/bin/env bash
# `claude-kit lazy` — dispatcher. Each verb lives in cmd/lazy/<verb>.sh.

cmd_lazy() {
  local verb="${1:-help}"
  shift || true
  case "$verb" in
    ls|list)            source "$CLAUDE_KIT_LIB_DIR/cmd/lazy/ls.sh";       _lazy_ls "$@" ;;
    show|cat)           source "$CLAUDE_KIT_LIB_DIR/cmd/lazy/show.sh";     _lazy_show "$@" ;;
    add|enable)         source "$CLAUDE_KIT_LIB_DIR/cmd/lazy/add.sh";      _lazy_add "$@" ;;
    rm|remove|disable)  source "$CLAUDE_KIT_LIB_DIR/cmd/lazy/rm.sh";       _lazy_rm "$@" ;;
    project|proj)       source "$CLAUDE_KIT_LIB_DIR/cmd/lazy/project.sh";  _lazy_project "$@" ;;
    new|scaffold)       source "$CLAUDE_KIT_LIB_DIR/cmd/lazy/new.sh";      _lazy_new "$@" ;;
    refresh|reload)     source "$CLAUDE_KIT_LIB_DIR/cmd/lazy/refresh.sh";  _lazy_refresh "$@" ;;
    bundle|bundles)     source "$CLAUDE_KIT_LIB_DIR/cmd/lazy/bundle.sh";   _lazy_bundle "$@" ;;
    doctor)             source "$CLAUDE_KIT_LIB_DIR/cmd/lazy/doctor.sh";   _lazy_doctor ;;
    help|-h|--help|"")  _lazy_help ;;
    *) die "lazy: unknown verb '$verb' (try: ls show add rm project new refresh bundle doctor)" ;;
  esac
}
