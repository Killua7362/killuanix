#!/usr/bin/env bash
# Shared helpers for `claude-kit lazy` — catalog discovery, target parsing,
# and item-finding. Sourced by all cmd/lazy/*.sh files.

_lazy_help() {
  cat <<'EOF'
claude-kit lazy — opt-in catalog of skills, agents, commands, plugins.

  ls [<catalog>] [--type <kind>]    List sub-catalogs or contents
  show <type> <name>                Print item (path + rendered file if md)
  add <type> <name>                 Symlink into ./.claude/<type>/ (project scope)
  add <catalog>:<name>              Tag a catalog (type auto-detected); required
                                    to disambiguate a name in multiple catalogs
  add <catalog>/<type>/<name>       Fully-qualified equivalent
  rm <type> <name>                  Remove from project scope
  project [--global]                List project-scope items (--global also lists catalog)
  new <name>                        Scaffold a new sub-catalog under Notes/claude/lazy/
  refresh [--dry] [<name>]          Regenerate catalog.json from contents; no
                                    <name> = every editable catalog
  bundle ls|show|add|rm|status      Manage named groups (e.g. `bundle add ruflo`)
  doctor [--strict] [--quiet]       Validate lazy.json + every catalog.json
                                    (JSON, shape, dead paths, inherit, dups)
EOF
}

# All sub-catalog names (any subdir of $LAZY_DIR with catalog.json).
_lazy_catalogs() {
  [ -d "$LAZY_DIR" ] || return 0
  find "$LAZY_DIR" -mindepth 2 -maxdepth 2 -name catalog.json 2>/dev/null \
    | sed -e "s|^$LAZY_DIR/||" -e 's|/catalog.json$||' \
    | sort
}

# _lazy_catalog_json <catalog> [<seen-csv>]
# Echo a catalog's EFFECTIVE JSON — its own skills/agents/commands/plugins
# merged with everything pulled in by an optional top-level `inherit` list,
# resolved recursively. This is what every reader (resolve / available /
# count / ls) sees, so a "virtual" catalog can compose other catalogs.
#
# inherit schema (in catalog.json):
#   "inherit": [
#     { "from": "personal" },                                  # all of it
#     { "from": "claude-code-java",
#       "exclude": { "skills": ["git-commit"], "agents": [] } },# all but these
#     { "from": "wshobson",
#       "include": { "commands": ["review"] } }                # ONLY these
#   ]
# Per source: `include` = whitelist (a type absent from `include` yields
# nothing of that type); `exclude` = blacklist (a type absent yields all of
# it); neither = inherit everything. Both may co-exist (include, then drop
# excluded). Dedup is by name; the catalog's own entries win, then
# earlier-listed sources win over later ones. Cycles are broken (a repeat
# visit contributes only its own explicit entries).
_lazy_catalog_json() {
  local cat="$1" seen="${2:-}"
  local f="$LAZY_DIR/$cat/catalog.json"
  [ -f "$f" ] || { echo '{"skills":[],"agents":[],"commands":[],"plugins":[]}'; return 0; }
  local own; own=$(jq -c '{skills:(.skills//[]),agents:(.agents//[]),commands:(.commands//[]),plugins:(.plugins//[])}' "$f" 2>/dev/null || echo '{}')
  # Cycle guard: on a repeat visit, contribute own entries only.
  case ",$seen," in *",$cat,"*) printf '%s' "$own"; return 0 ;; esac
  seen="${seen:+$seen,}$cat"

  local n; n=$(jq -r '(.inherit // []) | length' "$f" 2>/dev/null || echo 0)
  local eff="$own" i
  for ((i = 0; i < n; i++)); do
    local sel; sel=$(jq -c ".inherit[$i]" "$f")
    local from; from=$(printf '%s' "$sel" | jq -r '.from // empty')
    [ -n "$from" ] || continue
    local srcjson; srcjson=$(_lazy_catalog_json "$from" "$seen")
    eff=$(jq -cn --argjson eff "$eff" --argjson src "$srcjson" --argjson sel "$sel" '
      def snames(a): (a // []) | map(.name);
      def pick(items; t):
        ($sel.include // null) as $inc
        | ($sel.exclude // null) as $exc
        | (if $inc == null then (items // [])
           elif (($inc[t]) // null) == null then []
           else (items // []) | map(select(.name as $x | ($inc[t] | index($x)) != null)) end) as $base
        | (if $exc == null then $base
           elif (($exc[t]) // null) == null then $base
           else $base | map(select(.name as $x | ($exc[t] | index($x)) == null)) end);
      def merge(o; a): (o // []) + ((a // []) | map(select(.name as $x | (snames(o) | index($x)) == null)));
      {
        skills:   merge($eff.skills;   pick($src.skills;   "skills")),
        agents:   merge($eff.agents;   pick($src.agents;   "agents")),
        commands: merge($eff.commands; pick($src.commands; "commands")),
        plugins:  merge($eff.plugins;  pick($src.plugins;  "plugins"))
      }')
  done
  printf '%s' "$eff"
}

_lazy_count() {
  local c="$1" type="$2"
  _lazy_catalog_json "$c" | jq -r --arg t "$type" '(.[$t] // []) | length' 2>/dev/null || echo 0
}

# _lazy_type_keys <type-or-empty> — echo the catalog.json list keys to
# search. Empty (or "any") = the three resource types (plugins are
# registry-less, never auto-detected). Returns 64 on an unknown type.
_lazy_type_keys() {
  case "${1:-}" in
    ""|any)           echo "skills agents commands" ;;
    skill|skills)     echo "skills" ;;
    agent|agents)     echo "agents" ;;
    command|commands) echo "commands" ;;
    plugin|plugins)   echo "plugins" ;;
    *) return 64 ;;
  esac
}

# _lazy_resolve <type-or-empty> <name> [<hint_catalog>]
# Echoes "<catalog>\t<listkey>\t<path>" lines for every match. An empty
# <type> auto-detects across skills/agents/commands. <hint_catalog>
# restricts the search to one catalog (the `<catalog>:` tag). Caller
# decides ambiguity policy.
_lazy_resolve() {
  local type="$1" name="$2" hint="${3:-}"
  local keys; keys=$(_lazy_type_keys "$type") || return 64
  local c cj t p
  for c in $(_lazy_catalogs); do
    if [ -n "$hint" ] && [ "$c" != "$hint" ]; then continue; fi
    cj=$(_lazy_catalog_json "$c")
    for t in $keys; do
      p=$(printf '%s' "$cj" | jq -r --arg k "$t" --arg n "$name" \
            '(.[$k] // []) | map(select(.name == $n)) | .[0].path // empty' 2>/dev/null)
      if [ -n "$p" ]; then printf '%s\t%s\t%s\n' "$c" "$t" "$p"; fi
    done
  done
}

# _lazy_find <type> <name> [<hint_catalog>]
# Back-compat 2-column view ("<catalog>\t<path>") over _lazy_resolve.
_lazy_find() {
  _lazy_resolve "$@" | awk -F'\t' 'NF>=3 {print $1 "\t" $3}'
}

# _lazy_barename <raw> — strip a leading "<catalog>:" qualifier, echoing
# just the resource name (the filesystem / symlink identity).
_lazy_barename() {
  case "$1" in
    *:*) local q="${1%%:*}" n="${1#*:}"
         if [ -n "$q" ] && [ -n "$n" ]; then printf '%s' "$n"; return; fi ;;
  esac
  printf '%s' "$1"
}

# _lazy_hint <raw> — echo the "<catalog>:" qualifier (empty if none).
_lazy_hint() {
  case "$1" in
    *:*) local q="${1%%:*}" n="${1#*:}"
         if [ -n "$q" ] && [ -n "$n" ]; then printf '%s' "$q"; return; fi ;;
  esac
  printf ''
}

# RES_CAT / RES_TYPE / RES_PATH — set by _lazy_resolve_one on success.
#
# _lazy_resolve_one <type-or-empty> <name> [<hint>]
# Pure (no output). Return codes:
#   0  unique match          -> RES_CAT/RES_TYPE(listkey)/RES_PATH set
#   64 not found anywhere
#   65 ambiguous (>1 catalog; only possible with no <hint>)
#   66 wrong tag: <hint> given, name absent there but present elsewhere
_lazy_resolve_one() {
  local type="$1" name="$2" hint="${3:-}"
  RES_CAT=""; RES_TYPE=""; RES_PATH=""
  local matches; matches=$(_lazy_resolve "$type" "$name" "$hint")
  local n; n=$(printf '%s' "$matches" | grep -c . 2>/dev/null || true)
  if [ "$n" -gt 1 ]; then return 65; fi
  if [ "$n" = 1 ]; then
    RES_CAT=$( printf '%s' "$matches" | head -1 | cut -f1)
    RES_TYPE=$(printf '%s' "$matches" | head -1 | cut -f2)
    RES_PATH=$(printf '%s' "$matches" | head -1 | cut -f3)
    return 0
  fi
  if [ -n "$hint" ] && [ -n "$(_lazy_resolve "$type" "$name" "")" ]; then
    return 66
  fi
  return 64
}

# _lazy_fmt_matches <name> — read resolve TSV on stdin, print one
# "  <catalog>:<name>   (<type>)" suggestion per line.
_lazy_fmt_matches() {
  awk -F'\t' -v n="$1" '{ ty=$2; sub(/s$/,"",ty); printf "  %s:%s   (%s)\n", $1, n, ty }'
}

# _lazy_available <type-or-empty> — every catalog item of that type as
# "  <catalog>:<name>", sorted. Fallback listing for a not-found error.
_lazy_available() {
  local keys; keys=$(_lazy_type_keys "$1") || keys="skills agents commands"
  local c cj t
  for c in $(_lazy_catalogs); do
    cj=$(_lazy_catalog_json "$c")
    for t in $keys; do
      printf '%s' "$cj" | jq -r --arg c "$c" --arg k "$t" '(.[$k] // [])[] | "  \($c):\(.name)"' 2>/dev/null
    done
  done | sort
}

# _lazy_explain_rc <rc> <type> <name> [<hint>] — print the human error
# for a _lazy_resolve_one return code to stderr. Shared by the CLI and
# `project sync` so both surface the identical message.
_lazy_explain_rc() {
  local rc="$1" type="$2" name="$3" hint="${4:-}"
  local label="${type:-skill|agent|command}"
  case "$rc" in
    65)
      { echo "lazy: '$name' ($label) is ambiguous — it exists in multiple catalogs:"
        _lazy_resolve "$type" "$name" "" | _lazy_fmt_matches "$name"
        echo "disambiguate with  <catalog>:$name"; } >&2 ;;
    66)
      { echo "lazy: wrong tag — '$name' is not in catalog '$hint'. It exists in:"
        _lazy_resolve "$type" "$name" "" | _lazy_fmt_matches "$name"; } >&2 ;;
    *)
      { echo "lazy: not found: $label/$name${hint:+ (in catalog '$hint')}"
        echo "available:"
        _lazy_available "$type"; } >&2 ;;
  esac
}

# Parse a lazy target into PARSED_CAT / PARSED_TYPE / PARSED_NAME.
# Accepted shapes (PARSED_TYPE may be empty → caller auto-detects):
#   <catalog>/<type>/<name>   composite (two slashes)
#   <type> <name>             classic; <name> may carry a <catalog>: tag
#   <catalog>:<name>          single token, tagged, type auto-detected
#   <name>                    single token, bare, type auto-detected
_lazy_parse_target() {
  local first="${1:-}" second="${2:-}"
  PARSED_CAT=""
  PARSED_TYPE=""
  PARSED_NAME=""
  if [ -z "$first" ]; then return 1; fi

  # Composite <catalog>/<type>/<name> (contains two slashes).
  if printf '%s' "$first" | grep -q '/.*/'; then
    PARSED_CAT="${first%%/*}"
    local rest="${first#*/}"
    PARSED_TYPE="${rest%%/*}"
    PARSED_NAME="${rest#*/}"
    [ -n "$PARSED_TYPE" ] && [ -n "$PARSED_NAME" ]
    return
  fi

  if [ -n "$second" ]; then
    PARSED_TYPE="$first"     # <type> <name>
    PARSED_NAME="$second"
  else
    PARSED_NAME="$first"     # single token: <catalog>:<name> or <name>
  fi

  # Peel a leading "<catalog>:" qualifier off the name.
  PARSED_CAT=$(_lazy_hint "$PARSED_NAME")
  PARSED_NAME=$(_lazy_barename "$PARSED_NAME")

  [ -n "$PARSED_NAME" ]
}

_lazy_project_dir() { echo "$PWD/.claude"; }

_lazy_bundle_files() {
  # Echo `<catalog> <name>` for every bundle JSON in the lazy dir.
  # `find -L` follows symlinks because each upstream sub-catalog's bundles/
  # dir (e.g. ruflo/bundles/) is a symlink into a nix-store derivation
  # produced by claude-resources/.
  [ -d "$LAZY_DIR" ] || return 0
  find -L "$LAZY_DIR" -mindepth 3 -maxdepth 3 -path '*/bundles/*.json' 2>/dev/null \
    | sed -e "s|^$LAZY_DIR/||" -e 's|/bundles/| |' -e 's|\.json$||' \
    | sort
}

_lazy_bundle_resolve() {
  # _lazy_bundle_resolve <name>  -> echoes "<catalog> <path>" or empty.
  # Accepts <catalog>/<name> or bare <name>.
  local target="$1"
  local hint=""
  if printf '%s' "$target" | grep -q '/'; then
    hint="${target%%/*}"
    target="${target#*/}"
  fi
  local matches=""
  local line c name
  while read -r line; do
    c="${line%% *}"
    name="${line#* }"
    if [ -n "$hint" ] && [ "$c" != "$hint" ]; then continue; fi
    if [ "$name" = "$target" ]; then
      matches="$matches$c $LAZY_DIR/$c/bundles/$name.json"$'\n'
    fi
  done < <(_lazy_bundle_files)
  printf '%s' "$matches"
}

_lazy_bundle_state() { echo "$PWD/.claude/.lazy-bundles.json"; }

# _lazy_find_project_config — walk up from $PWD looking for claude-kit.nix.
# Echoes the absolute path on hit, exits non-zero on miss. Stops at $HOME
# and at filesystem root.
_lazy_find_project_config() {
  local d="$PWD"
  while [ "$d" != "/" ] && [ "$d" != "${HOME%/}" ]; do
    if [ -f "$d/claude-kit.nix" ]; then printf '%s' "$d/claude-kit.nix"; return 0; fi
    d=$(dirname "$d")
  done
  return 1
}

# _lazy_resolve_mcp <name>
# Echo the JSON stanza for an MCP server by name. Looks up two sources in
# order:
#   1. $XDG_DATA_HOME/claude-kit/all-mcp-servers.json — full registry catalog
#      emitted by claude.nix (includes `optional = true` entries excluded
#      from the global mcpServers wiring).
#   2. ~/.claude.json under .mcpServers — runtime servers added via
#      `claude mcp add` or otherwise registered by Claude Code itself.
# Empty output + non-zero rc on miss in both sources.
_lazy_resolve_mcp() {
  local name="$1"
  local catalog="${XDG_DATA_HOME:-$HOME/.local/share}/claude-kit/all-mcp-servers.json"
  local stanza=""
  if [ -f "$catalog" ]; then
    stanza=$(jq -c --arg n "$name" '.[$n] // empty' "$catalog" 2>/dev/null)
  fi
  if [ -z "$stanza" ] && [ -f "$HOME/.claude.json" ]; then
    stanza=$(jq -c --arg n "$name" '.mcpServers[$n] // empty' "$HOME/.claude.json" 2>/dev/null)
  fi
  [ -n "$stanza" ] || return 1
  printf '%s' "$stanza"
}

# _lazy_state_file — flake-managed sync state, sibling of .lazy-bundles.json.
_lazy_state_file() { echo "$PWD/.claude/.flake-managed.json"; }

# _lazy_inherit_plan <inherit-json-array-of-strings>
# Expand a claude-kit.nix `inheritCatalogs` list — a plain list of catalog
# NAMES — into concrete per-type tokens. Every entry of every named catalog
# (its full *effective* set, i.e. including what that catalog itself
# inherits) is pulled in; there is no per-catalog include/exclude. Echoes:
#   { errors:[…],
#     skills:["<catalog>:<name>", …], agents:[…], commands:[…],
#     plugins:["<slug>", …] }
# skills/agents/commands are "<catalog>:<name>" tags (resolve unambiguously,
# symlink under the bare name); plugins are bare slugs.
#
# Catalogs are simply **merged**: listing two catalogs that share a name (or
# a name one inherits from the other) is NOT an error — the union is taken,
# deduped by bare name, first-listed catalog wins the tag. So listing both a
# base catalog and one that partially inherits it yields the union of both
# (the base's un-inherited members are included). A repeated catalog name is
# processed once (and the caller collapses the duplicate in the file).
# The only error is naming a catalog that doesn't exist.
_lazy_inherit_plan() {
  local inh="$1"
  local -a errors=() tok_skills=() tok_agents=() tok_commands=() tok_plugins=()
  declare -A seen seencat
  local n; n=$(printf '%s' "$inh" | jq 'length' 2>/dev/null || echo 0)
  local i
  for ((i = 0; i < n; i++)); do
    local from; from=$(printf '%s' "$inh" | jq -r ".[$i]")
    [ -n "$from" ] || continue
    [ -n "${seencat[$from]:-}" ] && continue      # duplicate name → once
    seencat[$from]=1
    if [ ! -f "$LAZY_DIR/$from/catalog.json" ]; then
      errors+=("inheritCatalogs: unknown catalog '$from'"); continue
    fi
    local cat; cat=$(_lazy_catalog_json "$from")
    local t nm
    for t in skills agents commands plugins; do
      while IFS= read -r nm; do
        [ -n "$nm" ] || continue
        local kkey="$t"$'\x1f'"$nm"
        [ -n "${seen[$kkey]:-}" ] && continue     # already have it (merge/dedup)
        seen[$kkey]=1
        case "$t" in
          skills)   tok_skills+=("$from:$nm") ;;
          agents)   tok_agents+=("$from:$nm") ;;
          commands) tok_commands+=("$from:$nm") ;;
          plugins)  tok_plugins+=("$nm") ;;
        esac
      done < <(printf '%s' "$cat" | jq -r --arg t "$t" '(.[$t]//[])[].name')
    done
  done
  _arr_json() { printf '%s\n' "${@:-}" | jq -R . | jq -s 'map(select(. != ""))'; }
  jq -cn \
    --argjson errors   "$(_arr_json "${errors[@]:-}")" \
    --argjson skills   "$(_arr_json "${tok_skills[@]:-}")" \
    --argjson agents   "$(_arr_json "${tok_agents[@]:-}")" \
    --argjson commands "$(_arr_json "${tok_commands[@]:-}")" \
    --argjson plugins  "$(_arr_json "${tok_plugins[@]:-}")" \
    '{errors:$errors,skills:$skills,agents:$agents,commands:$commands,plugins:$plugins}'
}

# _lazy_type_to_key <type-arg> — normalize a CLI type argument (singular or
# plural) into the canonical top-level list key used in claude-kit.nix.
# Echoes the key, exits non-zero on unknown type.
_lazy_type_to_key() {
  case "${1:-}" in
    skill|skills)     echo skills ;;
    agent|agents)     echo agents ;;
    command|commands) echo commands ;;
    plugin|plugins)   echo plugins ;;
    mcp|mcps)         echo mcp ;;
    *) return 1 ;;
  esac
}

# _project_edit_list <claude-kit.nix> <add|rm> <list-key> <item>
# Insert or remove "<item>" inside the top-level `<list-key> = [ ... ];`
# block of a claude-kit.nix file. Schema is flat list-of-strings (see
# den/templates/claude-kit.nix), so a line-oriented awk pass is enough.
# On success the file is rewritten atomically (mktemp+mv) and exit 0.
# Exit codes:
#   2 — list key not present in file
#   3 — list opens and closes on the same line (needs reformat)
#   4 — add: item already present in the block (no-op)
#   5 — add: closing `];` not found (malformed file)
#   6 — rm:  item not present in the block (no-op)
#   1 — other failure
_project_edit_list() {
  local cfg="$1" mode="$2" key="$3" item="$4"
  [ -f "$cfg" ] || { echo "claude-kit.nix not found: $cfg" >&2; return 1; }
  case "$mode" in add|rm) ;; *) echo "_project_edit_list: bad mode '$mode'" >&2; return 1 ;; esac
  case "$key" in skills|agents|commands|plugins|mcp|inheritCatalogs) ;; *) echo "_project_edit_list: bad list key '$key'" >&2; return 1 ;; esac
  [ -n "$item" ] || { echo "_project_edit_list: empty item" >&2; return 1; }

  local tmp; tmp=$(mktemp)
  awk -v mode="$mode" -v key="$key" -v item="$item" '
    BEGIN { state = 0; saw_key = 0; same_line = 0; dup = 0; inserted = 0; removed = 0 }
    state == 0 {
      pat = "^[[:space:]]*" key "[[:space:]]*=[[:space:]]*\\["
      if (match($0, pat)) {
        saw_key = 1
        rest = substr($0, RSTART + RLENGTH)
        if (index(rest, "]") > 0) { same_line = 1; state = 2 } else { state = 1 }
        print
        next
      }
      print
      next
    }
    state == 1 {
      # Closing line of the block: `<indent>];` optionally with trailing # comment.
      if (match($0, "^[[:space:]]*\\];")) {
        if (mode == "add" && !dup) {
          if (match($0, "^[[:space:]]+")) {
            cwhite = substr($0, 1, RLENGTH)
          } else {
            cwhite = ""
          }
          printf "%s  \"%s\"\n", cwhite, item
          inserted = 1
        }
        print
        state = 2
        next
      }
      # Strip leading whitespace + optional trailing comma to compare bare.
      bare = $0
      sub(/^[[:space:]]+/, "", bare)
      sub(/[[:space:]]*,?[[:space:]]*$/, "", bare)
      if (mode == "rm") {
        if (bare == "\"" item "\"") { removed = 1; next }
      }
      if (mode == "add") {
        if (bare !~ /^#/ && bare == "\"" item "\"") dup = 1
      }
      print
      next
    }
    state == 2 { print; next }
    END {
      if (!saw_key)                       exit 10
      if (same_line)                      exit 11
      if (mode == "add" && dup)           exit 12
      if (mode == "add" && !inserted)     exit 13
      if (mode == "rm"  && !removed)      exit 14
    }
  ' "$cfg" > "$tmp"
  local rc=$?
  case "$rc" in
    0)  mv -f "$tmp" "$cfg"; return 0 ;;
    10) rm -f "$tmp"; echo "claude-kit.nix: list '$key' not found in $cfg" >&2; return 2 ;;
    11) rm -f "$tmp"; echo "claude-kit.nix: list '$key' is on a single line; reformat to one entry per line and retry" >&2; return 3 ;;
    12) rm -f "$tmp"; return 4 ;;
    13) rm -f "$tmp"; echo "claude-kit.nix: closing '];' for '$key' not found" >&2; return 5 ;;
    14) rm -f "$tmp"; return 6 ;;
    *)  rm -f "$tmp"; echo "claude-kit.nix: edit failed (awk rc=$rc)" >&2; return 1 ;;
  esac
}

# _project_load_sync — source cmd/project.sh once so _project_sync /
# _project_eval / _project_show etc. are available in this shell. No-op
# if already loaded.
_project_load_sync() {
  if ! declare -F _project_sync >/dev/null; then
    # shellcheck source=../cmd/project.sh
    source "$CLAUDE_KIT_LIB_DIR/cmd/project.sh"
  fi
}
