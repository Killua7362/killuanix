# shellcheck shell=bash
# .den/ (per-binding state dir) + project-dir helpers + activity log + lastop +
# reflog + project scaffold.
#
# All host-side binding state lives in a single `.den/` directory at the bound
# cwd (git-style), NOT flattened as `.den-*` siblings:
#   .den/meta.json      binding marker + applied-symlinks ledger + lastop
#   .den/meta.json.lock flock target
#   .den/reflog.jsonl   bind/unbind history
#   .den/generations/   per-op ledger snapshots
# Legacy flat layouts (`.den-meta.json` etc.) are auto-migrated on first bind
# (_den_migrate_if_legacy), so older bound dirs upgrade transparently.

# ---- .den dir + path helpers ---------------------------------------------
_den_dir()     { printf '%s/.den\n' "$1"; }
_meta_path()   { printf '%s/.den/meta.json\n' "$1"; }
_reflog_path() { printf '%s/.den/reflog.jsonl\n' "$1"; }
_lock_path()   { printf '%s/.den/meta.json.lock\n' "$1"; }

# _meta_file: existing meta path for an arbitrary (possibly un-migrated) dir —
# new layout preferred, legacy fallback, else the canonical new path. For
# read-only inspection of dirs the bind walkers haven't migrated yet.
_meta_file() { # <dir>
  if [ -f "$1/.den/meta.json" ]; then printf '%s/.den/meta.json\n' "$1"
  elif [ -f "$1/.den-meta.json" ]; then printf '%s/.den-meta.json\n' "$1"
  else printf '%s/.den/meta.json\n' "$1"; fi
}

# _den_is_bound_dir: 0 if <dir> holds a binding marker (new or legacy).
_den_is_bound_dir() { [ -f "$1/.den/meta.json" ] || [ -f "$1/.den-meta.json" ]; }

# _den_migrate_if_legacy: move a flat `.den-*` layout into `.den/`. Idempotent;
# no-op if there's no legacy marker or the dir is already migrated.
_den_migrate_if_legacy() { # <root>
  local root="$1"
  [ -f "$root/.den-meta.json" ] || return 0
  [ -f "$root/.den/meta.json" ] && return 0
  mkdir -p "$root/.den"
  mv -f "$root/.den-meta.json" "$root/.den/meta.json"
  [ -f "$root/.den-meta.json.reflog" ] && mv -f "$root/.den-meta.json.reflog" "$root/.den/reflog.jsonl"
  [ -f "$root/.den-meta.json.lock" ]   && rm -f "$root/.den-meta.json.lock"
  [ -d "$root/.den-generations" ]      && mv "$root/.den-generations" "$root/.den/generations"
  _info "migrated den metadata → $root/.den/" 2>/dev/null || true
}

_meta_init() { # _meta_init <root> <project-name>
  local root="$1" name="$2"
  local now
  now="$(date -Iseconds)"
  mkdir -p "$(_den_dir "$root")"
  cat >"$(_meta_path "$root")" <<EOF
{
  "schema_version": 1,
  "mode": "plain",
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
    .mode //= "plain" |
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

# _notes_path_committed: 0 if <path> (under the Notes vault) is safely in version
# control — tracked AND with no uncommitted working-tree changes. Used to gate
# destructive ops (den rm, den shelf clear) so removed content stays recoverable
# from git. "Committed / nothing to push" == working-tree clean for the path
# (local commits are assumed pushed regularly; we don't probe the remote). If
# Notes isn't a git repo the gate is a no-op (returns 0).
_notes_path_committed() { # <abs path under $DEN_NOTES>
  local p="$1"
  git -C "$DEN_NOTES" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  [ -z "$(git -C "$DEN_NOTES" status --porcelain -- "$p" 2>/dev/null)" ] || return 1
  [ -n "$(git -C "$DEN_NOTES" ls-files -- "$p" 2>/dev/null)" ] || return 1
  return 0
}

# ---- archived (hidden) projects -----------------------------------------
# Archive is a convention on the IMMEDIATE children of `projects/` ONLY: a
# project dir whose (flat, single-segment) name starts with '.' is archived —
# den will not list, resolve, create, or bind it. Rename `projects/<name>` →
# `projects/.<name>` to shelve / back it up without deleting it; rename back to
# un-archive. This NEVER applies to files or dirs *inside* a project: a pushed
# `.env` / `.claude/` is real, den-tracked content (the file walker deliberately
# walks dotfiles). So `projects/.dirA` archives dirA and everything under it,
# but `projects/dirA/.env` (or `projects/dirA/dirB`) is just content.
#
# The predicate takes a BARE project name (a single path segment). Callers that
# hold a path must reduce it to the immediate-child basename first (see list.sh).
_project_name_is_archived() { # <bare project name>
  case "$1" in
    */*) return 1 ;;   # has a slash → not a top-level project name → never an archive marker
    .*)  return 0 ;;
    *)   return 1 ;;
  esac
}

# _reject_hidden_project: abort if the name refers to an archived project.
_reject_hidden_project() { # <name>
  _project_name_is_archived "$1" && _err 2 \
    "'$1' is an archived (hidden) project — invisible to den" \
    "" "un-archive: rename $DEN_PROJECTS/$1 back without the leading dot"
  return 0
}

# ---- binding context resolution -----------------------------------------
# Globals set by the resolvers below (declared here so `set -u` reads are
# always safe once a resolver has run):
#   BOUND_MODE     always "plain" (retained for compat; single-mode now)
#   BOUND_ROOT     dir holding the .den/ binding
#   BOUND_PROJECT  project name
#   BOUND_PD       project dir ($DEN_PROJECTS/<name>)
BOUND_MODE=""; BOUND_ROOT=""; BOUND_PROJECT=""; BOUND_PD=""

# _resolve_bind_ctx: walk upward from cwd; on the first .den/ binding (or a
# legacy .den-meta.json, auto-migrated) set the BOUND_* globals and return 0.
# On no marker, clear them and return 1.
# Does NOT abort — wrappers decide policy.
_resolve_bind_ctx() {
  local d
  d="$(pwd -P)"
  while [ "$d" != "/" ]; do
    if _den_is_bound_dir "$d"; then
      _den_migrate_if_legacy "$d"
      BOUND_MODE="plain"; BOUND_ROOT="$d"
      BOUND_PROJECT="$(_meta_get "$d" .project)"
      BOUND_PD="$(_project_dir_for "$BOUND_PROJECT")"
      return 0
    fi
    d="$(dirname -- "$d")"
  done
  BOUND_MODE=""; BOUND_ROOT=""; BOUND_PROJECT=""; BOUND_PD=""
  return 1
}

# _bind_ctx: HARD variant — abort (exit 64) if unbound. Sets BOUND_* in the
# CURRENT shell, so the exit propagates to the caller (unlike the old
# `out="$(_require_bound)"` idiom whose subshell exit was swallowed, leaving
# an empty root that downstream commands treated as "/").
_bind_ctx() {
  _resolve_bind_ctx || _err 64 "no den binding found from $(pwd -P) upward" \
    "" "run 'den new' or 'den init' here"
}

# _try_bind_ctx: SOFT variant — return 1 (no abort, no output) if unbound.
# For commands that degrade gracefully (activate/doctor/gc).
_try_bind_ctx() { _resolve_bind_ctx; }

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
  mkdir -p "$(_den_dir "$root")"
  "$DEN_HELPER_BIN" append-jsonl --path "$(_reflog_path "$root")" --entry "$entry" || true
}

# ---- presets / skeleton --------------------------------------------------
_scaffold_project() { # _scaffold_project <name> <preset>
  local name="$1" preset="$2"
  _reject_hidden_project "$name"   # '.'-prefixed names are reserved for archive
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
.den/
.den-staging/
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
