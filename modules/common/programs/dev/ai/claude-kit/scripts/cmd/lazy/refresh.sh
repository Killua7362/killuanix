#!/usr/bin/env bash
# `lazy refresh [--dry] [<name>]` — regenerate <name>/catalog.json from the
# catalog's skills/ agents/ commands/ dir contents. Hand-authored `plugins`
# and `inherit` are preserved (neither is walked from a directory), so a
# composed/virtual catalog survives a refresh.
#
#   no <name>   refresh EVERY editable catalog (nix-managed ones — whose
#               catalog.json is a store symlink — are skipped; they can't be
#               written through).
#   --dry       show what WOULD change (unified diff of the pretty JSON) and
#               write nothing. It's a preview, not a gate — always exits 0
#               when it ran; use `lazy doctor` to fail on problems.

# Build the fresh catalog.json for one catalog dir on stdout. No side effects.
_lazy_refresh_render() {
  local d="$1"
  _walk_skills() {
    [ -d "$d/skills" ] || { echo '[]'; return; }
    {
      local sd
      for sd in "$d/skills"/*/; do
        [ -d "$sd" ] || continue
        local sn; sn=$(basename "$sd")
        jq -n --arg name "$sn" --arg path "${sd%/}" '{name: $name, path: $path}'
      done
    } | jq -s 'sort_by(.name)'
  }
  _walk_md() {
    local sub="$1"
    [ -d "$d/$sub" ] || { echo '[]'; return; }
    {
      local f
      for f in "$d/$sub"/*.md; do
        [ -f "$f" ] || continue
        local fn; fn=$(basename "$f" .md)
        jq -n --arg name "$fn" --arg path "$f" '{name: $name, path: $path}'
      done
    } | jq -s 'sort_by(.name)'
  }

  local skills agents commands plugins inherit
  skills=$(_walk_skills)
  agents=$(_walk_md agents)
  commands=$(_walk_md commands)
  # Preserve hand-authored `plugins` and `inherit` (neither is walked from a
  # directory) so refreshing a composed/virtual catalog is non-destructive.
  if [ -f "$d/catalog.json" ]; then
    plugins=$(jq '.plugins // []' "$d/catalog.json")
    inherit=$(jq -c '.inherit // []' "$d/catalog.json")
  else
    plugins='[]'; inherit='[]'
  fi
  # No root `name` field — a catalog's identity is its directory name.
  jq -n \
    --argjson skills "$skills" \
    --argjson agents "$agents" \
    --argjson commands "$commands" \
    --argjson plugins "$plugins" \
    --argjson inherit "$inherit" \
    '(if ($inherit | length) > 0 then {inherit: $inherit} else {} end)
     + {skills: $skills, agents: $agents, commands: $commands, plugins: $plugins}'
}

# _lazy_refresh_one <name> <dry:0|1> — refresh (or preview) a single catalog.
# Echoes a status line; returns 0 on success/skip, 1 on hard error.
_lazy_refresh_one() {
  local name="$1" dry="$2"
  local d="$LAZY_DIR/$name"
  if [ ! -d "$d" ]; then
    echo "  [skip] no such catalog: $name" >&2; return 1
  fi
  # A store-symlinked catalog.json is nix-managed and read-only — writing
  # through the symlink would hit the store (EROFS) or clobber the link.
  if [ -L "$d/catalog.json" ]; then
    echo "  [skip] $name (nix-managed — catalog.json is a store symlink)"
    return 0
  fi

  local new; new=$(_lazy_refresh_render "$d")

  if [ "$dry" = 1 ]; then
    local cur='{}'
    [ -f "$d/catalog.json" ] && cur=$(jq -S '.' "$d/catalog.json" 2>/dev/null || echo '{}')
    local newp; newp=$(printf '%s' "$new" | jq -S '.')
    if [ "$cur" = "$newp" ]; then
      echo "  [ok]   $name — up-to-date"
    else
      echo "  [diff] $name — would change $d/catalog.json:"
      diff <(printf '%s\n' "$cur") <(printf '%s\n' "$newp") | sed 's/^/         /'
    fi
    return 0
  fi

  printf '%s\n' "$new" > "$d/catalog.json"
  echo "  [ok]   refreshed: $d/catalog.json"
}

_lazy_refresh() {
  local dry=0 name=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --dry|--dry-run) dry=1; shift ;;
      -h|--help)
        echo "usage: claude-kit lazy refresh [--dry] [<name>]"
        echo "  no <name>  refresh every editable catalog (nix-managed skipped)"
        echo "  --dry      preview changes without writing"
        return 0 ;;
      -*) die "lazy refresh: unknown flag $1" ;;
      *)  [ -z "$name" ] || die "lazy refresh: unexpected extra arg '$1'"; name="$1"; shift ;;
    esac
  done

  # Single named catalog.
  if [ -n "$name" ]; then
    _lazy_refresh_one "$name" "$dry"
    return
  fi

  # All catalogs.
  [ -d "$LAZY_DIR" ] || die "lazy dir does not exist: $LAZY_DIR"
  if [ "$dry" = 1 ]; then
    echo "lazy refresh --dry (all catalogs):"
  else
    echo "lazy refresh (all catalogs):"
  fi
  local c rc=0
  for c in $(_lazy_catalogs); do
    _lazy_refresh_one "$c" "$dry" || rc=1
  done
  return "$rc"
}
