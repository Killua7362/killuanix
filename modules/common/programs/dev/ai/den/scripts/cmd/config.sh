# shellcheck shell=bash
den_cmd_config() {
  local sub="${1:-list}"; shift || true
  local cfg="$DEN_CONFIG"
  mkdir -p "$(dirname "$cfg")"; touch "$cfg"
  case "$sub" in
    get) [ -n "${1:-}" ] || _err 2 "usage: den config get <key>"
         grep -E "^$1 *=" "$cfg" | sed -E "s/^$1 *= *//; s/^\"//; s/\"$//" || true;;
    set) [ "${1:-}" ] && [ "${2:-}" ] || _err 2 "usage: den config set <key> <value>"
         sed -i "/^$1 *=/d" "$cfg"
         echo "$1 = \"$2\"" >>"$cfg";;
    unset) [ -n "${1:-}" ] || _err 2 "usage: den config unset <key>"
           sed -i "/^$1 *=/d" "$cfg";;
    list) cat "$cfg" 2>/dev/null;;
    *) _err 2 "config: unknown subcommand $sub (try get|set|unset|list)";;
  esac
}
