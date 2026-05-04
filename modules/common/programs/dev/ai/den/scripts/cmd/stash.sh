# shellcheck shell=bash
den_cmd_stash() {
  local series="${1:-}"
  [ -n "$series" ] || _err 2 "usage: den stash <SERIES> [--message M] [--edit]"
  shift || true
  local edit=0 msg=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --edit) edit=1; shift;;
      --message|-m) msg="${2:-}"; shift 2;;
      *) shift;;
    esac
  done

  local out
  out="$(_require_bound)"
  local root proj
  root="$(echo "$out" | sed -n 1p)"
  proj="$(echo "$out" | sed -n 2p)"
  local pd
  pd="$(_project_dir_for "$proj")"

  cd "$root"
  git rev-parse --show-toplevel >/dev/null 2>&1 || _err 2 "$root is not a git repo"

  local series_dir="$pd/patches/$series"
  [ -e "$series_dir" ] && _err 2 "series exists: $series"
  mkdir -p "$series_dir"

  local branch upstream remote remote_url base
  branch="$(git rev-parse --abbrev-ref HEAD)"
  upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || echo "")"
  remote="$(git config --get "branch.$branch.remote" 2>/dev/null || echo origin)"
  remote_url="$(git remote get-url "$remote" 2>/dev/null || echo "")"
  if [ -n "$upstream" ]; then
    base="$(git merge-base HEAD "$upstream" 2>/dev/null || git rev-parse HEAD)"
  else
    base="$(git rev-parse HEAD)"
  fi

  # 1. format-patch for committed-and-ahead, with anchor-blob capture
  local n_committed=0
  local -a anchor_shas=()
  if [ -n "$upstream" ] && [ "$(git rev-list --count "$upstream..HEAD")" -gt 0 ]; then
    git format-patch --output-directory "$series_dir" "$upstream..HEAD" >/dev/null
    n_committed="$(find "$series_dir" -maxdepth 1 -name '*.patch' | wc -l)"
    _cas_init
    # Capture each modified file's pre-image blob into the CAS, keyed
    # by the git blob SHA-1 so `git am --3way` can recover it later.
    local f
    for f in "$series_dir"/*.patch; do
      [ -f "$f" ] || continue
      # Find the patch's parent commit: line "From <sha> Mon ..."
      local pc
      pc="$(awk '/^From [0-9a-f]+/{print $2; exit}' "$f")"
      [ -n "$pc" ] || pc="$base"
      # Files modified in this patch: scan "diff --git a/X b/Y" lines.
      local files
      files="$(awk '/^diff --git a\// {sub(/^a\//,"",$3); print $3}' "$f" 2>/dev/null \
               | sort -u)"
      local rel
      while IFS= read -r rel; do
        [ -z "$rel" ] && continue
        # Pre-image blob: the file's content at parent of this commit.
        local blob_sha
        blob_sha="$(git rev-parse "$pc^:$rel" 2>/dev/null || echo "")"
        [ -z "$blob_sha" ] && continue
        # Skip if already cached.
        local existing
        existing="$(_cas_anchor_lookup "$blob_sha" 2>/dev/null || true)"
        if [ -z "$existing" ] || ! _cas_has "$existing"; then
          local cas_sha
          cas_sha="$(git cat-file blob "$blob_sha" | _cas_put)"
          _cas_record_anchor "$blob_sha" "$cas_sha"
          anchor_shas+=("$blob_sha")
        else
          anchor_shas+=("$blob_sha")
        fi
      done <<<"$files"
    done

    # Inject Den-Series:, Den-Anchor: (commit), and Den-Anchor-Blob:
    # trailers (one line per captured blob SHA) into each patch.
    local trailer_blobs=""
    local s
    for s in "${anchor_shas[@]}"; do
      trailer_blobs+="\nDen-Anchor-Blob: $s"
    done
    for f in "$series_dir"/*.patch; do
      [ -f "$f" ] || continue
      # `sed` substitutes the first `---` separator only.
      sed -i "0,/^---$/{s|^---$|Den-Series: $series\nDen-Anchor: $base${trailer_blobs}\n---|}" "$f" || true
    done

    # Record CAS refs for this series (one per patch, content-addressed).
    local n=1
    for f in "$series_dir"/*.patch; do
      [ -f "$f" ] || continue
      local sha
      sha="$(_cas_put "$f")"
      _cas_record_ref "$proj" "$series" "$n" "$sha"
      n=$((n + 1))
    done
  fi

  # 2. index.diff (staged)
  if ! git diff --cached --quiet; then
    git diff --cached >"$series_dir/index.diff"
  fi

  # 3. worktree.diff (unstaged)
  if ! git diff --quiet; then
    git diff >"$series_dir/worktree.diff"
  fi

  # 4. untracked.tar
  local untracked
  untracked="$(git ls-files --others --exclude-standard | tr '\n' '\0')"
  if [ -n "$untracked" ]; then
    (cd "$root" && git ls-files --others --exclude-standard -z | tar --null -T - -cf "$series_dir/untracked.tar")
  fi

  local dirty=false
  [ -f "$series_dir/index.diff" ] || [ -f "$series_dir/worktree.diff" ] || [ -f "$series_dir/untracked.tar" ] && dirty=true

  # meta.toml
  local meta="$series_dir/meta.toml"
  cat >"$meta" <<EOF
schema_version = 1
series_name = "$series"
project = "$proj"
branch = "$branch"
upstream = "$upstream"
remote = "$remote"
remote_url = "$remote_url"
base_commit = "$base"
dirty = $dirty
created_at = "$(date -Iseconds)"
host = "$DEN_HOST"
message = ${msg:+\"$msg\"}${msg:-\"\"}
EOF

  if [ "$edit" = 1 ] && _has_tty; then
    : >"$series_dir/description.md"
    ${EDITOR:-nvim} "$series_dir/description.md" || true
  fi

  _record_activity "$proj" stash 0 0
  echo "stashed → $series_dir"
  echo "  committed patches: $n_committed"
  echo "  dirty:             $dirty"
}
