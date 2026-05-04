# shellcheck shell=bash
den_cmd_completion() {
  local shell="${1:-bash}"
  case "$shell" in
    bash)
      cat <<'EOF'
_den() {
  local cur prev cmds
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  cmds="new init list ls status add ignore rm re-add restore pull clean sync stash apply patches log last-applied reflog generations rollback diff which cd exec activate prompt gc cas config hooks doctor completion help explain version"
  if [ "$COMP_CWORD" -eq 1 ]; then
    COMPREPLY=( $(compgen -W "$cmds" -- "$cur") )
    return 0
  fi
  case "$prev" in
    init|cd|exec|sync|rollback|diff)
      local projects
      projects="$(den list --plain 2>/dev/null | sed 's/^[* ] //; s/  *.*//')"
      COMPREPLY=( $(compgen -W "$projects" -- "$cur") );;
    apply|stash)
      local out series
      out="$(den ls 2>/dev/null | grep -A99 '^patches' | tail -n +2 | sed 's/^  //')"
      COMPREPLY=( $(compgen -W "$out" -- "$cur") );;
    *) COMPREPLY=( $(compgen -f -- "$cur") );;
  esac
}
complete -F _den den
EOF
      ;;
    zsh)
      cat <<'EOF'
#compdef den
_den() {
  local cmds
  cmds=(new init list ls status add ignore rm re-add restore pull clean sync stash apply patches log last-applied reflog generations rollback diff which cd exec activate prompt gc cas config hooks doctor completion help explain version)
  if (( CURRENT == 2 )); then
    _describe 'den command' cmds
    return
  fi
  case "$words[2]" in
    init|cd|exec|sync|rollback|diff)
      local projects
      projects=( ${(f)"$(den list --plain 2>/dev/null | sed 's/^[* ] //; s/  *.*//')"} )
      _describe 'project' projects;;
    *) _files;;
  esac
}
_den "$@"
EOF
      ;;
    fish)
      cat <<'EOF'
complete -c den -f
complete -c den -n "__fish_use_subcommand" -a "new init list ls status add ignore rm re-add restore pull clean sync stash apply patches log last-applied reflog generations rollback diff which cd exec activate prompt gc cas config hooks doctor completion help explain version"
complete -c den -n "__fish_seen_subcommand_from init cd exec sync rollback diff" -a "(den list --plain 2>/dev/null | sed 's/^[* ] //; s/  *.*//')"
EOF
      ;;
    *) _err 2 "completion: unknown shell '$shell' (try bash|zsh|fish)";;
  esac
}
