#!/usr/bin/env bash
cmd_plugin() {
  local sub="${1:-list}"
  shift || true
  case "$sub" in
    install|uninstall|enable|disable|update|list)
      exec claude plugin "$sub" "$@" ;;
    *) die "plugin: unknown subcommand '$sub' (install|uninstall|enable|disable|update|list)" ;;
  esac
}
