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
  cmds="new init clone bootstrap list ls status add ignore hide unhide rm re-add restore pull clean sync shelf stash apply patches log last-applied reflog generations rollback diff which cd exec activate prompt gc cas config hooks doctor completion help explain version"
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
    unhide)
      local hid
      hid="$(den ls 2>/dev/null | awk '/^hidden \(/{f=1;next} /:$/{f=0} f{sub(/^  */,"");if(NF)print}')"
      COMPREPLY=( $(compgen -W "$hid" -- "$cur") );;
    clone)
      COMPREPLY=( $(compgen -W "sync drift" -- "$cur") );;
    --devshell)
      local langs
      if [ -n "$DEN_DEV_TEMPLATES_DIR" ] && [ -d "$DEN_DEV_TEMPLATES_DIR" ]; then
        langs="$(for d in "$DEN_DEV_TEMPLATES_DIR"/*/; do
          [ -f "$d/flake.nix" ] && basename "$d"
        done)"
      fi
      COMPREPLY=( $(compgen -W "$langs" -- "$cur") );;
    *)
      if [ "${COMP_WORDS[1]}" = "new" ] && [[ "$cur" == --* ]]; then
        COMPREPLY=( $(compgen -W "--path --from --preset --devshell --no-devshell" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi;;
  esac
}
complete -F _den den
EOF
      ;;
    zsh)
      cat <<'EOF'
_den() {
  local cmds
  cmds=(new init clone bootstrap list ls status add ignore hide unhide rm re-add restore pull clean sync shelf stash apply patches log last-applied reflog generations rollback diff which cd exec activate prompt gc cas config hooks doctor completion help explain version)
  if (( CURRENT == 2 )); then
    _describe 'den command' cmds
    return
  fi
  case "$words[CURRENT-1]" in
    --devshell)
      local langs=()
      if [[ -n "$DEN_DEV_TEMPLATES_DIR" && -d "$DEN_DEV_TEMPLATES_DIR" ]]; then
        local d
        for d in "$DEN_DEV_TEMPLATES_DIR"/*/; do
          [[ -f "$d/flake.nix" ]] && langs+=("${d:t}")
        done
      fi
      _describe 'dev-template' langs
      return;;
  esac
  case "$words[2]" in
    init|cd|exec|sync|rollback|diff)
      local projects
      projects=( ${(f)"$(den list --plain 2>/dev/null | sed 's/^[* ] //; s/  *.*//')"} )
      _describe 'project' projects;;
    unhide)
      local hid
      hid=( ${(f)"$(den ls 2>/dev/null | awk '/^hidden \(/{f=1;next} /:$/{f=0} f{sub(/^  */,"");if(NF)print}')"} )
      _describe 'hidden pattern' hid;;
    clone)
      local cv=(sync drift); _describe 'clone verb' cv;;
    new)
      if [[ "$words[CURRENT]" == --* ]]; then
        local opts=(--path --from --preset --devshell --no-devshell)
        _describe 'option' opts
      else
        _files
      fi;;
    *) _files;;
  esac
}
compdef _den den
EOF
      ;;
    fish)
      cat <<'EOF'
complete -c den -f
complete -c den -n "__fish_use_subcommand" -a "new init clone bootstrap list ls status add ignore hide unhide rm re-add restore pull clean sync shelf stash apply patches log last-applied reflog generations rollback diff which cd exec activate prompt gc cas config hooks doctor completion help explain version"
complete -c den -n "__fish_seen_subcommand_from init cd exec sync rollback diff" -a "(den list --plain 2>/dev/null | sed 's/^[* ] //; s/  *.*//')"
# path-taking subcommands: re-enable file completion (den has -f globally)
complete -c den -n "__fish_seen_subcommand_from hide add ignore rm re-add restore" -F
complete -c den -n "__fish_seen_subcommand_from unhide" -a "(den ls 2>/dev/null | awk '/^hidden \\(/{f=1;next} /:\$/{f=0} f{sub(/^  */,\"\");if(NF)print}')"
complete -c den -n "__fish_seen_subcommand_from clone" -a "sync drift"
complete -c den -n "__fish_seen_subcommand_from new" -l path -l from -l preset -l devshell -l no-devshell
complete -c den -n "__fish_seen_subcommand_from new; and __fish_prev_arg_in --devshell" -a "(if test -n \"\$DEN_DEV_TEMPLATES_DIR\"; for d in \$DEN_DEV_TEMPLATES_DIR/*/; test -f \"\$d/flake.nix\"; and basename \$d; end; end)"
EOF
      ;;
    *) _err 2 "completion: unknown shell '$shell' (try bash|zsh|fish)";;
  esac
}
