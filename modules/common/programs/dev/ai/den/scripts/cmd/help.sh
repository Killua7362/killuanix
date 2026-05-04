# shellcheck shell=bash
den_cmd_help() {
  local topic="${1:-}"
  case "$topic" in
    ""|main)
      cat <<'EOF'
den — project-scoped symlink + patch manager

Usage: den <command> [args]

Binding lifecycle:
  new <NAME> [.|--path P] [--from N] [--preset bare|minimal|claude-full]
  init <NAME> [.|--path P]   bind cwd to existing project; runs pull
  clean [--yes]              remove this binding's symlinks; keep host-only files
  list                       projects in Notes/projects/

Files in the binding:
  ls                         list files (symlinked / host-only / untracked)
  status [--diff] [--json]   drift report (5 buckets)
  add <path>... [--force] [--as-dir]
  ignore <path>...           mark host-only
  rm <path>... [--yes]       delete from project
  re-add <path>...           ingest a real file replacing a project symlink
  restore <path>...          undo `den add` (move file back, keep content here)
  pull [--dry-run] [--ignore-failures] [--resume]

Patches:
  stash <SERIES> [--message M] [--edit]
  apply <SERIES> [--checkout] [--dry-run] [--reverse]
                             [--continue] [--abort] [--onto <ref>]
  patches [--tag T] [--json]
  sync <OTHER>               copy non-patch content from another project

History / observability:
  log [--this-host|--all-hosts]
  last-applied               table: hosts × last-pull-time × drift × project
  reflog [--cwd|--project N] [expire --older-than D]
  generations [--json]
  rollback [<gen>] [--dry-run]
  diff <gen-a> [<gen-b>]

Convenience:
  which <abs-path>           which project owns this path on this host
  cd <NAME>                  print bound cwd of project on this host
  exec <NAME> <cmd>...       run cmd in bound dir of project
  activate                   print eval-able env (DEN_PROJECT, etc.)
  prompt                     short status string for prompt integration

Maintenance:
  gc [--dry-run] [--rebuild] CAS + generations garbage collect
  cas {verify|show <sha>}    inspect content-addressed store
  config get/set/unset/list  layered config (mirrors git config)
  hooks trust <name>         record host-hook SHA
  doctor [--strict]          health check; exit code = drift count
  completion {bash|zsh|fish} print shell completion script
  help [topic] | explain <code>

Topics: bindings, manifest, patches, hooks, exit-codes, prompt, nix
Custom subcommands: any `den-foo` on PATH is reachable as `den foo`.
EOF
      ;;
    bindings)
      cat <<'EOF'
bindings — how den maps cwds to projects

Each working directory is "bound" to at most one project via
.den-meta.json (host-side, gitignored). The project source lives at
$DEN_NOTES/projects/<NAME>/ and is shared via the Notes git repo.

Path resolution (only for `new` and `init`):
  - default: prefer git root if cwd is in a work-tree, else cwd
  - .       : force cwd, with warning if in a git repo
  - --path P: literal path

Other commands walk upward from cwd until .den-meta.json is found.
EOF
      ;;
    patches)
      cat <<'EOF'
patches — git-aware stash/apply with re-anchor metadata

`den stash <SERIES>` captures uncommitted (working tree + index) AND
commits ahead of upstream into a numbered series under
Notes/projects/<NAME>/patches/<SERIES>/. Each patch carries
Den-Series: and Den-Anchor: trailers so the series is self-describing
after rebase, cherry-pick, or amend.

`den apply <SERIES>` runs `git am --3way` against the recorded base.
--onto <ref> re-anchors when upstream forced-pushed.
EOF
      ;;
    hooks)
      cat <<'EOF'
hooks — den lifecycle hooks (distinct from Claude Code hooks)

Den fires lifecycle events around mutating operations:
  pre/post-pull, pre/post-clean, pre/post-add, pre/post-sync,
  pre/post-stash, pre/post-apply

Two scopes:
  shared — Notes/projects/<N>/hooks/<event>  (committed)
  host   — ~/.local/share/den/overlay/<N>/hooks/<event> (Nix-managed)

Host hooks must be SHA-trusted before they run:
  den hooks trust <event>
EOF
      ;;
    exit-codes)
      cat <<'EOF'
exit codes
  0   ok
  1   drift / generic failure
  2   usage error
  64  unbound — no .den-meta.json found
  65  manifest corrupt
  69  missing runtime tool
  75  lock held — another den process is running
  78  config error
EOF
      ;;
    prompt)
      cat <<'EOF'
prompt integration

Add to ~/.config/starship.toml:

  [custom.den]
  command = "den prompt"
  when = "test -f .den-meta.json"
  format = "[$output]($style) "
  style = "bold cyan"

`den prompt` prints "<project>" or "<project>!N" (drift count cached).
EOF
      ;;
    manifest)
      cat <<'EOF'
manifest — Notes/projects/<N>/manifest.toml

Hybrid mode: every file under files/ is auto-walked. The manifest
only stores entries that need metadata (mode, host filter, kind=dir).

Schema:
  [[entry]]
  src = "files/foo"
  kind = "symlink" | "dir"     # "bind" parses but defers to v2
  mode = "0644"
  host = "killua"              # optional: skip on other hosts
EOF
      ;;
    nix)
      cat <<'EOF'
Nix integration — programs.den.projects

Declare hooks/files per project; choose scope (host or shared):

  programs.den.projects.myproj = {
    hooks.pre-pull = {
      scope = "host";
      text = "echo killua-only";
    };
    files.".env.host" = {
      scope = "host";
      text = '''APP_HOST=killua''';
    };
  };

Host-scope writes to ~/.local/share/den/overlay/<N>/.
Shared-scope writes to Notes/projects/<N>/, refusing to clobber files
a user has edited (marker: `# den-managed (do not edit)`).
EOF
      ;;
    *)
      _err 2 "unknown help topic: $topic (try: bindings|patches|hooks|exit-codes|prompt|manifest|nix)"
      ;;
  esac
}

den_cmd_explain() {
  local code="${1:-}"
  case "$code" in
    DRIFT-001) echo "manifest hash mismatches recorded value; pull to reconcile" ;;
    I1) echo "every applied symlink's source must resolve under project files/ or overlay" ;;
    I2) echo "every symlink target on disk must match .den-meta.json.symlinks" ;;
    I3) echo 'Den-Anchor: SHA missing locally and from CAS - try `den apply <S> --onto <ref>`' ;;
    I4) echo "every CAS object filename must equal sha256 of its content" ;;
    I5) echo "every reflog entry's prev_project must be loadable from Notes" ;;
    I6) echo "every trusted-hook SHA must match the file content on disk" ;;
    I7) echo "no dangling symlinks pointing into the project tree" ;;
    *) _err 2 "unknown code: $code (try DRIFT-001 or I1-I7)" ;;
  esac
}

den_cmd_version() {
  echo "den (killuanix flake) — v1"
}
