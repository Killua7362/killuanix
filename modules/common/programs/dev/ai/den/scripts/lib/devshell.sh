# shellcheck shell=bash
# dev-shell template helpers — bootstrap `the-nix-way/dev-templates` into
# a new den project and wire it up for nix-direnv.
#
# Source path lives in $DEN_DEV_TEMPLATES_DIR (set by the Nix wrapper from
# the `dev-templates` flake input). Each subdir is a self-contained
# template with a `flake.nix`.

# _devshell_list — print available template names, one per line.
# Filters out the upstream repo's top-level scaffolding (.github, README,
# the repo-level flake.nix that just lists everything, etc.). A real
# template is a subdir containing its own `flake.nix`.
_devshell_list() {
  local d
  [ -n "${DEN_DEV_TEMPLATES_DIR:-}" ] || return 0
  [ -d "$DEN_DEV_TEMPLATES_DIR" ] || return 0
  for d in "$DEN_DEV_TEMPLATES_DIR"/*/; do
    [ -f "$d/flake.nix" ] || continue
    basename "$d"
  done | sort
}

# _devshell_pick_interactive — prompt the user for a template; echo the
# chosen name on stdout, or empty on cancel. Uses fzf if on PATH, falls
# back to numbered `select` otherwise.
_devshell_pick_interactive() {
  local langs choice
  langs="$(_devshell_list)"
  [ -n "$langs" ] || { _warn "no dev templates available at $DEN_DEV_TEMPLATES_DIR"; return 1; }

  if command -v fzf >/dev/null 2>&1; then
    choice="$(printf '%s\n' "$langs" | fzf \
      --prompt='dev-shell template> ' \
      --height=40% --reverse --no-multi 2>/dev/null || true)"
  else
    local PS3='Select template (or 0 to cancel): '
    local opts=()
    while IFS= read -r line; do opts+=("$line"); done <<<"$langs"
    select choice in "${opts[@]}"; do
      [ -n "$choice" ] && break
      [ "$REPLY" = "0" ] && { choice=""; break; }
    done
  fi
  printf '%s' "$choice"
}

# _devshell_resolve <flag-value> <skip-flag>
# Resolves the user's intent into the final template name (echoed on
# stdout, possibly empty). Inputs:
#   $1 — explicit --devshell value (or empty)
#   $2 — "1" if --no-devshell was passed, else "0"
# Behavior:
#   - explicit lang → validated and echoed
#   - --no-devshell → empty
#   - TTY + neither flag → prompt (yes/no, then picker)
#   - non-TTY + neither flag → empty (skip; preserves CI/script behavior)
_devshell_resolve() {
  local lang="$1" skip="$2"
  if [ "$skip" = "1" ]; then
    return 0
  fi
  if [ -n "$lang" ]; then
    if ! _devshell_list | grep -qxF "$lang"; then
      local avail
      avail="$(_devshell_list | paste -sd, -)"
      _err 2 "unknown dev-template: $lang" \
        "$DEN_DEV_TEMPLATES_DIR has no '$lang' subdir" \
        "available: ${avail:-<none>}"
    fi
    printf '%s' "$lang"
    return 0
  fi
  if ! _has_tty; then
    return 0
  fi
  if ! _yesno "Bootstrap a Nix dev shell from the-nix-way/dev-templates?"; then
    return 0
  fi
  _devshell_pick_interactive
}

# _devshell_apply <project-dir> <lang>
# Copies the chosen template into <project-dir>/files/, registers
# flake.nix (and flake.lock if present) as kind="hardlink" in
# manifest.toml, writes a `use flake` .envrc, and adds .direnv/ to
# .denignore. Idempotent — safe to call against an existing project.
_devshell_apply() {
  local pd="$1" lang="$2" src="$DEN_DEV_TEMPLATES_DIR/$lang"
  [ -d "$src" ] || _err 2 "unknown dev-template: $lang"
  [ -f "$src/flake.nix" ] || _err 2 "template '$lang' has no flake.nix"

  # Don't clobber an existing flake — the user has likely customized it.
  if [ -f "$pd/files/flake.nix" ]; then
    _warn "files/flake.nix already exists — leaving it untouched"
  else
    # Copy the template. Store paths are read-only, so relax perms after.
    cp -r "$src/." "$pd/files/"
    chmod -R u+w "$pd/files/"
  fi

  # Hardlink the flake — symlink-out-of-tree breaks `nix develop`
  # (documented gotcha in den/CLAUDE.md → manifest help).
  _set_manifest_kind "$pd" "flake.nix" "hardlink"
  [ -f "$pd/files/flake.lock" ] && _set_manifest_kind "$pd" "flake.lock" "hardlink"

  # .envrc — symlink is fine; direnv evaluates it in the bound cwd.
  if [ ! -f "$pd/files/.envrc" ]; then
    printf 'use flake\n' >"$pd/files/.envrc"
  fi

  # Keep direnv's working dir out of project history.
  if ! grep -qxF '.direnv/' "$pd/.denignore" 2>/dev/null; then
    printf '.direnv/\n' >>"$pd/.denignore"
  fi
}

# _devshell_post_pull <bound-cwd>
# After the post-`new` _do_pull has materialized the symlinks/hardlinks,
# auto-allow the .envrc on TTY (so `cd <cwd>` immediately enters the
# shell). Non-TTY contexts get a printed hint instead. No-op if the
# project doesn't carry a .envrc (i.e. --no-devshell or skipped prompt).
_devshell_post_pull() {
  local cwd="$1"
  [ -f "$cwd/.envrc" ] || return 0
  if _has_tty && command -v direnv >/dev/null 2>&1; then
    if ( cd "$cwd" && direnv allow ) 2>/dev/null; then
      _info "direnv: allowed; the dev shell will load on next \`cd\` into $cwd."
    else
      _warn "direnv allow failed in $cwd — run it manually to enable the dev shell."
    fi
  else
    _info "Run \`direnv allow\` in $cwd to load the dev shell."
  fi
}
