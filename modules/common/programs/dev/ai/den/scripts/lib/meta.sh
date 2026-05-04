# shellcheck shell=bash
# .den-meta.json + project-dir helpers + activity log + lastop + reflog +
# project scaffold.

# ---- meta file helpers ---------------------------------------------------
_meta_path() { printf '%s/.den-meta.json\n' "$1"; }

_meta_init() { # _meta_init <root> <project-name>
  local root="$1" name="$2"
  local now
  now="$(date -Iseconds)"
  cat >"$(_meta_path "$root")" <<EOF
{
  "schema_version": 1,
  "project": "$name",
  "host": "$DEN_HOST",
  "bound_at": "$now",
  "manifest_hash": "sha256-empty",
  "symlinks": [],
  "host_only": [],
  "trusted_hooks": {},
  "conflict_choices": {},
  "lastop": null
}
EOF
}

_meta_get() { # _meta_get <root> <jq-path>
  jq -r "$2" "$(_meta_path "$1")" 2>/dev/null
}

# _meta_ensure_keys: idempotently fills in any missing keys on the meta
# file (handles forward-compat for files written by older den versions
# and shields downstream `|=` mutations from `null` operands).
_meta_ensure_keys() {
  local root="$1" m
  m="$(_meta_path "$root")"
  [ -f "$m" ] || return 0
  local tmp
  tmp="$(mktemp)"
  jq '
    .schema_version //= 1 |
    .project //= "" |
    .host //= "" |
    .bound_at //= "" |
    .manifest_hash //= "sha256-empty" |
    .symlinks //= [] |
    .host_only //= [] |
    .trusted_hooks //= {} |
    .conflict_choices //= {} |
    .lastop //= null
  ' "$m" >"$tmp" && mv "$tmp" "$m"
}

# _meta_update: atomically apply a jq expression to the meta file.
# The expression is evaluated *after* default-key normalization so it
# can safely use `|=` against `.symlinks`, `.host_only`, etc. without
# worrying about `null` operands.
#
# Extra `--arg` / `--argjson` pairs may be passed after the expression
# for safe interpolation of user data; e.g.
#   _meta_update "$root" \
#     '.host_only |= (. + [$p] | unique)' --arg p "$rel"
_meta_update() { # _meta_update <root> <jq-expr> [--arg|--argjson name val ...]
  local root="$1" expr="$2"
  shift 2
  local m
  m="$(_meta_path "$root")"
  [ -f "$m" ] || _err 65 "manifest missing: $m"
  _meta_ensure_keys "$root"
  local tmp
  tmp="$(mktemp)"
  if ! jq "$@" "$expr" "$m" >"$tmp" 2>/dev/null; then
    rm -f "$tmp"
    _err 65 "manifest update failed (expr: $expr)"
  fi
  # Validate output is non-empty JSON before committing.
  if [ ! -s "$tmp" ] || ! jq empty "$tmp" 2>/dev/null; then
    rm -f "$tmp"
    _err 65 "manifest update produced invalid JSON"
  fi
  mv "$tmp" "$m"
}

_project_dir_for() { printf '%s/%s\n' "$DEN_PROJECTS" "$1"; }

_require_bound() { # echoes bound-root, project-name on stdout (two lines) or errors
  local root proj
  root="$(_find_binding_root)" || _err 64 "no .den-meta.json found from $(pwd -P) upward"
  proj="$(_meta_get "$root" .project)"
  printf '%s\n%s\n' "$root" "$proj"
}

# ---- activity log + lastop ----------------------------------------------
_activity_dir() { printf '%s/.activity\n' "$(_project_dir_for "$1")"; }

_record_activity() { # _record_activity <project> <op> <exit> [drift_after] [cwd]
  local proj="$1" op="$2" rc="$3" drift="${4:-0}" cwd="${5:-$(pwd -P)}"
  local ad
  ad="$(_activity_dir "$proj")"
  mkdir -p "$ad"
  local entry
  entry="$(jq -n \
    --arg host "$DEN_HOST" \
    --arg op "$op" \
    --argjson rc "$rc" \
    --argjson drift "$drift" \
    --arg cwd "$cwd" \
    '{host:$host, op:$op, exit:$rc, drift_after:$drift, cwd:$cwd}')"
  "$DEN_HELPER_BIN" append-jsonl --path "$ad/$DEN_HOST.jsonl" --entry "$entry" || true
}

_record_lastop() { # _record_lastop <root> <op> <exit> <drift>
  local root="$1" op="$2" rc="$3" drift="$4"
  local ts
  ts="$(date -Iseconds)"
  local m
  m="$(_meta_path "$root")"
  [ -f "$m" ] || return 0
  _meta_ensure_keys "$root"
  local tmp
  tmp="$(mktemp)"
  if jq --arg op "$op" --arg ts "$ts" \
        --argjson rc "$rc" --argjson drift "$drift" \
        '.lastop = {cmd: $op, exit: $rc, ts: $ts, drift_after: $drift}' \
        "$m" >"$tmp" 2>/dev/null && [ -s "$tmp" ] && jq empty "$tmp" 2>/dev/null; then
    mv "$tmp" "$m"
  else
    rm -f "$tmp"
    _warn "could not update lastop"
  fi
}

_append_reflog() { # _append_reflog <root> <op> <prev_project> <new_project>
  local root="$1" op="$2" prev="$3" new="$4"
  local entry
  entry="$(jq -n --arg host "$DEN_HOST" --arg op "$op" --arg prev "$prev" --arg new "$new" \
    '{host:$host, op:$op, prev_project:$prev, new_project:$new}')"
  "$DEN_HELPER_BIN" append-jsonl --path "$root/.den-meta.json.reflog" --entry "$entry" || true
}

# ---- presets / skeleton --------------------------------------------------
_scaffold_project() { # _scaffold_project <name> <preset>
  local name="$1" preset="$2"
  local pd
  pd="$(_project_dir_for "$name")"
  [ -e "$pd" ] && _err 2 "project already exists: $pd"
  mkdir -p "$pd/files" "$pd/patches" "$pd/hooks" "$pd/.activity"

  # .den-project.toml
  local now
  now="$(date -Iseconds)"
  cat >"$pd/.den-project.toml" <<EOF
schema_version = 1
name = "$name"
created_at = "$now"
created_on_host = "$DEN_HOST"
visibility = "public"
preset = "$preset"
description = ""
EOF

  case "$preset" in
    bare)
      : >"$pd/.denignore"
      ;;
    minimal)
      : >"$pd/files/CLAUDE.md"
      cat >"$pd/.denignore" <<'EOF'
CLAUDE.local.md
EOF
      ;;
    claude-full|"")
      mkdir -p "$pd/files/.claude/commands" "$pd/files/.claude/agents" \
               "$pd/files/.claude/skills"  "$pd/files/.claude/output-styles"
      cat >"$pd/files/CLAUDE.md" <<'EOF'
# Project notes

Replace this with project-specific guidance for Claude Code.
EOF
      cat >"$pd/files/.claude/settings.json" <<'EOF'
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "permissions": {}
}
EOF
      cat >"$pd/files/.mcp.json" <<'EOF'
{
  "mcpServers": {}
}
EOF
      cat >"$pd/.denignore" <<'EOF'
# Per-host Claude state never leaves the host.
CLAUDE.local.md
.claude/settings.local.json
.env
.env.*
*.local.md
.den-meta.json
.den-meta.json.lock
.den-meta.json.reflog
.den-staging/
.den-generations/
EOF
      cat >"$pd/README.md" <<EOF
# $name

Created by \`den new\` on $now ($DEN_HOST).
EOF
      ;;
    *)
      _err 2 "unknown preset: $preset (try bare|minimal|claude-full)"
      ;;
  esac

  printf '%s\n' "$pd"
}
