# den

`den` — project-scoped symlink + patch manager. A bash CLI (`den`) that binds named projects under `Notes/projects/<NAME>/` to working directories via symlinks, plus a Python sidecar (`den-helper`) that handles the heavy ops (tree-walk, manifest hashing, JSONL ops, drift status, TOML I/O).

Originally a single 2944-line `den.nix` with a `writeShellApplication` body and an inlined `writers.writePython3Bin` body. Split into a directory so each subcommand lives in its own file with a real LSP and shellcheck/pyright. Behavior is unchanged — both bodies are wired to the same wrapper that the `den` and `den-helper` packages always shipped.

## Files

| File | Description |
|---|---|
| `default.nix` | HM module — declares `programs.den` options, builds the bash + python packages, wires shared/host overlay, completions, and the optional starship block. The bash wrapper exec's `bash $DEN_LIB_DIR/den.sh "$@"`; `den-helper` is a tiny entry stub that adds `helper/` to `sys.path` and calls `main()`. |
| `scripts/den.sh` | Bash entrypoint. Sets globals (`DEN_NOTES`, `DEN_PROJECTS`, `DEN_STATE`, `DEN_HOST`, `DEN_BINDINGS`, etc.), sources every `lib/*.sh` and `cmd/*.sh`, then dispatches `$1` to `den_cmd_<name>`. Falls back to `den-<name>` on PATH for git-style external subcommands. |
| `scripts/lib/common.sh` | Error template (`_err`/`_die`/`_warn`/`_info`), tty + yes/no helpers, `_find_binding_root`, `_resolve_target_path`, `_with_lock` (flock 9), `_maybe_zoxide_add`. |
| `scripts/lib/meta.sh` | `.den/` state-dir helpers (`_den_dir`/`_meta_path`/`_reflog_path`/`_lock_path`/`_meta_file`/`_den_is_bound_dir`/`_den_migrate_if_legacy`), meta I/O (`_meta_init`/`_meta_get`/`_meta_ensure_keys`/`_meta_update`), `_project_dir_for`, binding-context resolvers, activity-log + `lastop` + reflog writers, `_scaffold_project` (presets `bare`, `minimal`, `claude-full`). **`.den/` layout**: all host-side state lives in a single git-style dir at the bound cwd — `.den/meta.json` (marker + ledger), `.den/meta.json.lock`, `.den/reflog.jsonl`, `.den/generations/`. Legacy flat `.den-meta.json`/`.den-generations/` layouts are **auto-migrated** into `.den/` on first bind (`_den_migrate_if_legacy`, idempotent, called from both bind walkers). **Binding context**: `_resolve_bind_ctx` walks cwd upward for the nearest `.den/` binding (or a legacy marker, migrated) and sets globals `BOUND_MODE` (always `plain` — single-mode now), `BOUND_ROOT`/`BOUND_PROJECT`/`BOUND_PD`. `_bind_ctx` is the hard wrapper (aborts exit 64 if unbound — sets globals *in the current shell* so the exit actually propagates, unlike the retired `out="$(_require_bound)"` idiom whose subshell exit was swallowed → empty root treated as `/`); `_try_bind_ctx` is the soft wrapper (returns 1, no abort — used by `activate`/`doctor`/`gc`). Every command reads `$BOUND_ROOT`/`$BOUND_PROJECT` after one of these instead of re-parsing two stdout lines. |
| `scripts/lib/guard.sh` | **Leak guard + clone registry + hide registry** (see the sections below). Git-tree detection (`_guard_repo_top`/`_guard_git_dir`; `_guard_site_repo_top` = leaf-tolerant variant for `hide`); `<project>/clones.json` I/O (`_clones_{path,read,record}`, `_clone_path_for_rel`, `_clone_remote_for_path`; `_clone_present_ok` = pull gate: path present + git work tree + origin matches; `_clones_scan_repos`/`_clones_scan_json` = find git trees under root for `den clone sync`/`drift`); guard ops (`_guard_after_link` — exclude the site in its clone + record the clone, no-op off-repo; `_guard_unlink` — drop the exclude entry; `_guard_is_guarded` — leak check for `doctor`). **Hide registry** (`den hide`, tracked-in-vault-free git-exclude, `.denhidden` = source of truth): `_rel_under_root` (cwd-relative arg → path-from-root), `<project>/.denhidden` I/O (`_hidden_{path,list,record,remove}` — gitignore-syntax patterns), `_hidden_record_clone_for` (record the containing clone for host-2), and the **managed-block reconcile** (`_hidden_reassert_all` → `den-helper hidden-plan` → per-repo `_hidden_write_block`/`_hidden_expected_block`/`_hidden_lines_for_repo`, rewriting a `# BEGIN/END den-hidden` block in each present repo's `info/exclude`). |
| `scripts/lib/shelf.sh` | **Per-project shelf** (git-stash-like; see the section below). `_shelf_dir`/`_shelf_rows`/`_shelf_row_dir_for_id`; `_shelf_resolve_targets` (path/dir/`.` → den-managed rels from the ledger); `_shelf_add` (destructive remove into a row), `_shelf_materialize` + `_shelf_apply` (copy=apply / move=pop, conflict-aware), `_shelf_drop`/`_shelf_clear`/`_shelf_list`. |
| `scripts/lib/manifest.sh` | `manifest.toml` helpers — `_load_manifest_kinds` (returns JSON `{rel: kind}`), `_kind_for_rel`, `_set_manifest_kind` (insert/update/remove an entry; setting kind="symlink" deletes the override since symlink is the default), `_link_for_kind` (creates symlink or hardlink, errors on cross-fs hardlink). |
| `scripts/lib/bindings.sh` | Per-host bindings registry (`$DEN_BINDINGS`) — `_bindings_{init,add,remove,list_for,owner,prune}`. Powers `den cd` / `den which`. |
| `scripts/lib/store.sh` | Content-addressed store (CAS) at `$DEN_CAS_ROOT` — `_cas_{init,path_for,put,get,has,record_ref,record_anchor,anchor_lookup,restore_to_git}`. Used by `den stash` (anchor-blob capture) and `den apply` (3-way merge recovery). |
| `scripts/lib/hooks.sh` | `_run_hook` — dispatches lifecycle events (pre/post-pull/clean/add/sync/stash/apply) to shared (Notes-side) and host-overlay hooks; host hooks must be SHA-trusted via `den hooks trust <event>`. |
| `scripts/lib/generations.sh` | `_gen_dir`, `_write_generation` — per-cwd snapshots under `<root>/.den/generations/`. |
| `scripts/lib/devshell.sh` | `_devshell_{list,pick_interactive,resolve,apply,post_pull}` — bootstrap a `the-nix-way/dev-templates` flake into a new project's `files/` and wire it for `nix-direnv`. Used only by `cmd/new.sh`. Reads `$DEN_DEV_TEMPLATES_DIR` (set by the wrapper from the `dev-templates` flake input). Also drops the `claude-kit.nix` + augmented `.envrc` sibling files from `$DEN_CLAUDEKIT_SHIM` so `claude-kit project sync` activates on the next direnv reload. |
| `templates/claude-kit.nix` | Project-scoped Claude resources schema (pure attrset: `envVars`, `skills`, `agents`, `commands`, `plugins`, `mcp`, `inheritCatalogs`, plus the exclude/permission/hook/`restrictToDirs` hardening attrs). Copied next to the dev-template `flake.nix` by `_devshell_apply`. Consumed by `claude-kit project sync` / `claude-kit project envrc`. `inheritCatalogs` pulls whole lazy catalogs into the project (include/exclude granular control; `inherit` is a nix keyword so the attr is spelled out). |
| `templates/envrc` | `.envrc` that wires `use flake` together with `eval "$(claude-kit project envrc)"` and `claude-kit project sync --quiet`. Replaces the bare one-line `use flake` previously written by `_devshell_apply`. |
| `scripts/cmd/<name>.sh` | One file per subcommand. Each defines `den_cmd_<name>` (and any private `_do_<name>` helpers). Exact subcommand set (matches the dispatcher in `den.sh`): `help`, `version` + `explain` (in `help.sh`), `list`, `ls`, `status`, `new`, `init`, `clone`, `bootstrap`, `clean`, `pull`, `add`, `ignore`, `hide`, `unhide`, `rm`, `re-add`, `restore`, `sync`, `shelf`, `stash`, `apply`, `patches`, `which`, `cd`, `exec`, `activate`, `prompt`, `log`, `last-applied`, `reflog`, `generations`, `rollback`, `diff`, `gc`, `cas`, `config`, `hooks`, `doctor`, `completion`. |
| `scripts/cmd/init.sh` | `den init <NAME>` — binds cwd to an existing vault project and **stops** (no `pull`). Prints next-steps (`den bootstrap` + `den pull` when clones are registered, else just `den pull`). Materialization is deliberately separate so a fresh host can clone repos between bind and pull. |
| `scripts/cmd/clone.sh` | `den clone <verb>` dispatcher for the clone registry (`clones.json`). Bare/`help` → subcommand list; `sync [--dry]` → scan the bound tree for git repos (incl. nested) via `_clones_scan_json` + `den-helper clone-plan`, upsert new `{path,remote}` (unique paths; same remote at a new path appends), report conflicts (path present with a different remote) + no-remote entries in bulk (exit 1, partial apply OK); `drift` → report `clones.json` vs disk (untracked repos / missing clones / remote-drift / no-remote), non-mutating. |
| `scripts/cmd/bootstrap.sh` | `den bootstrap` — read-only **reconcile-to-actions**: compares cwd's structure against `clones.json` + the file ledger and prints ONLY the differences — `git clone <remote> <path>` (missing/empty path + remote), `mkdir -p <path>` (remote-less entry), warnings for occupied/mismatched paths — plus a `den pull` hint **only when there is drift pull can actually fix** (`_clone_present_ok`-gated missing-link count). Clean → "nothing to do". Never runs anything. Works both for a scratch checkout and for a mid-life drift / a new `clones.json` entry synced from another host. |
| `scripts/cmd/shelf.sh` | `den shelf <verb>` dispatcher (`add`/`list`/`apply`/`pop`/`drop`/`clear`; bare `den shelf` → `list`, so nothing is shelved by accident). `add` prompts for a non-blank name on a TTY (or `--name`); arg parsing + name prompt live here, mechanics in `lib/shelf.sh`. |
| `helper/main.py` | argparse dispatcher for `den-helper`. Subcommands: `walk`, `manifest-hash`, `status`, `render-status`, `append-jsonl`, `read-jsonl`, `parse-toml`, `write-toml`, `hidden-plan`, `ignore-match`, `clone-plan`. |
| `helper/lib/toml_io.py` | Minimal flat-table TOML serializer + `tomllib`/`tomli` re-export. |
| `helper/lib/ignore.py` | `.denignore` → compiled `pathspec` **gitwildmatch** spec (`load_ignore_spec`). Full gitignore semantics (`**`, `!` negation, `/`-anchoring, `*` not crossing `/`, `[...]`, trailing-`/` dir match). Backed by the `pathspec` lib wired into `den-helper`'s python env in `default.nix`. |
| `helper/lib/manifest.py` | Sorted recursive `_walk_files` and `_sha256_file`. |
| `helper/cmd/walk.py` | `walk` — list files under `--root`. |
| `helper/cmd/manifest_hash.py` | `manifest-hash` — sha256 over (path, content-sha) pairs of `<root>/files/`. |
| `helper/cmd/status.py` | `status` (5-bucket drift compute; `.denignore` via `load_ignore_spec`) + `render-status` (pretty-print, exit 1 on drift). |
| `helper/cmd/jsonl.py` | `append-jsonl` (auto-stamps `ts`) + `read-jsonl` (with `--tail`). |
| `helper/cmd/toml.py` | `parse-toml` → JSON; `write-toml` ← JSON on stdin. |
| `helper/cmd/hidden.py` | `hidden-plan` — maps each `.denhidden` gitignore pattern to the repo it applies to (root repo `.` or a registered clone path) and re-anchors it into that repo's frame, emitting `{repo: [lines]}` for the Bash managed-block writer. `ignore-match` — exit 0/1 on whether `<rel>` matches `.denignore` (used by `den add`'s ignore-check). |
| `helper/cmd/clones.py` | `clone-plan` — reconciles a disk scan of git repos (JSON `[{path,remote}]` on stdin) against `clones.json`, emitting `{add, conflicts, noRemote, unchanged, missing, untracked}` for `den clone sync`/`drift`. Enforces the invariant: unique paths, remotes may repeat. |

## Env-var contract

The bash wrapper in `default.nix` exports four store paths (`DEN_LIB_DIR`, `DEN_HELPER_BIN`, `DEN_DEV_TEMPLATES_DIR`, `DEN_CLAUDEKIT_SHIM`) and exec's `bash $DEN_LIB_DIR/den.sh "$@"`. Everything else is read by the bash from the user's environment (`HOSTNAME`, `XDG_DATA_HOME`, `XDG_CONFIG_HOME`, `EDITOR`, `DEN_NOTES`, etc.) with sensible defaults.

| Variable | Set by | Purpose |
|---|---|---|
| `DEN_LIB_DIR` | wrapper | Store path of the `den-scripts` derivation; `den.sh` sources `$DEN_LIB_DIR/{lib,cmd}/*.sh` from here. |
| `DEN_HELPER_BIN` | wrapper | Absolute path of the `den-helper` binary. Bash always invokes the helper as `"$DEN_HELPER_BIN" <subcmd>` — never relies on PATH so it survives a stripped environment. |
| `DEN_NOTES` | `home.sessionVariables` | Notes-vault path; defaults in bash to `$HOME/killuanix/Notes` if unset. |
| `DEN_DEV_TEMPLATES_DIR` | wrapper | Store path of the pinned `the-nix-way/dev-templates` flake input. `den new --devshell <lang>` (and the interactive picker) read template subdirs from here. Bumped by `nix flake lock --update-input dev-templates`. |
| `DEN_CLAUDEKIT_SHIM` | wrapper | Store path of the bundled `./templates/` dir holding `claude-kit.nix` + `envrc`. `_devshell_apply` copies these next to the dev-template `flake.nix` so projects opt in to `claude-kit project sync` on direnv reload. Unset → fallback to the legacy one-line `use flake` `.envrc`. |

**Do not** add `${...}` Nix interpolation inside `.sh` or `.py` files. Pass any new nix-injected value as another `export VAR=...` line in the `text` block of `default.nix`.

## How to add a new subcommand

1. Drop `scripts/cmd/<name>.sh` defining `den_cmd_<name>` (use `_<name>_helper` for private helpers — every `_*` is sourced into the same shell, so name collisions matter).
2. Add a `case` arm in `scripts/den.sh` dispatching `<name>) den_cmd_<name> "$@";;`.
3. Update the help text in `scripts/cmd/help.sh` and the completion lists in `scripts/cmd/completion.sh` (bash + zsh + fish, all hard-coded).
4. If it shells out to the python helper, also add a parser to `helper/main.py` and a `cmd_<name>` in `helper/cmd/<name>.py`. The library helpers under `helper/lib/` are import-only — keep `cmd_*` thin.

For an external `den-foo` git-style subcommand, just put the executable on PATH and call `den foo`; the dispatcher's `_try_external_subcommand` fallback exec's into it.

## Leak guard + clone registry (foreign-repo awareness)

There is a **single binding mode** (per-cwd `.den/` state dir). The old separate
"overlay mode" (`.den-overlay.toml`, `overlays/`, `den overlay`/`push`, `den replicate`)
was **merged into plain mode** — plain mode gained the only two things overlay had that
it lacked: a leak guard and a clone registry. `lib/guard.sh` holds both.

**The problem it solves:** when you `den add` a file that lives *inside a git clone*
(often a corporate repo you can pull but must never push your `CLAUDE.md`/IDE files
into), den moves the file to the project's `files/` store and drops a symlink back in
place. That bare symlink shows up in the clone's `git status`, and one stray `git add .`
would commit + push it to the foreign remote.

**The guard:** after (re)creating the site symlink, `_guard_after_link` runs
`git -C <site-dir> rev-parse --show-toplevel`. If the site sits inside a git work tree,
it appends `/​<rel-within-repo>` to that repo's `.git/info/exclude` — the symlink then
never appears in the repo's `git status`. `info/exclude` is chosen because it is
**local, never pushed, and not itself a tracked change** (unlike `.gitignore`). The rule
is **guard any git work tree** — we don't check for a remote, so a local-only repo is
guarded too and can't retroactively leak if a remote is added later. A file **not** inside
any git repo (top-level `flake.nix`/`Justfile`/`.envrc`, or a nested non-git file like
`legacy/README.md` sitting beside — not inside — the `legacy/frontend` clone) gets **no
guard** (nothing to leak to). This replaces overlay's `__root__` pseudo-clone: "not in a
repo → no guard" is now just the natural no-op branch of `_guard_after_link`.

**The clone registry** (`<project>/clones.json`, lives in the Notes vault so it travels
to the other host — the `.den/` state dir can't, it's host-only/gitignored):

```json
{ "clones": [ { "path": "<rel-to-binding-root>", "remote": "<origin-url>" } ] }
```

Every guarded add upserts the containing clone (path relative to the binding root +
`origin` remote), keyed by path. `path: "."` means the binding root itself is a repo.
This is what a fresh host needs to know which repos to `git clone`.

**Where the guard fires** — all link (re)creation paths call `_guard_after_link` (idempotent):
- `den add` (`_add_one`) — after the initial link. Prints `+ <rel> (guarded)` when the
  site is inside a repo.
- `den pull` (`_do_pull`) — reasserts the guard for every present link on each pull, and
  **gates materialization** via `_clone_present_ok`: a missing-link rel owned by a
  registered clone is wired **only** when that clone is properly present — the path exists,
  is a git work tree, and its origin matches `clones.json` (empty recorded remote ⇒ any).
  Otherwise the path is left **completely untouched** (missing / empty / non-repo / wrong
  remote) — no dirs created, no guard written, and (deliberately) **no `git clone` command
  printed**; that moved to `den bootstrap`. Root/non-clone files always materialize. So a
  host-2 setup is: `den init` → `den pull` (root files) → `den bootstrap` (clone commands)
  → clone what you need → `den pull` again (wires just the now-present clones). You need not
  clone everything at once; each pull only touches clones that are present + matching.
- `den re-add` (`_do_re_add`) — after re-ingesting an edited file.

`den rm` (`_do_rm`) calls `_guard_unlink` to drop the site's `info/exclude` entry.

**`den doctor`** adds two checks on top of the drift/dangling ones: **`[UNGUARDED]`** —
an in-repo symlink whose rel is *not* in `info/exclude` (the security failure: it would
leak; counted toward the non-zero exit) — and **`[info]/[CLONES]`** — registered clones
not present on this host (info by default, counted under `--strict`).

**Symlink kind:** plain mode's absolute out-of-tree links into the Notes `files/` store are
unchanged (with the cross-fs `--hardlink` fallback). The guard is orthogonal to link kind —
it only edits the foreign repo's `info/exclude`, never the link. (Note a hardlink *is* a
real file and would be committed to the foreign remote, so prefer the default symlink for
in-clone files.)

Two-host flow: edit → obsidian-git commits the vault (carrying `files/` + `clones.json`) →
on host 2, pull the vault, `den init <name>` the working root (**bind only, no pull**),
`den pull` (root/non-clone files), `den bootstrap` (prints the `git clone`/`mkdir`
commands), clone what you want, `den pull` again to wire + guard the now-present clones.

### Clone registry commands (`den clone`, `den bootstrap`)

`clones.json` is maintained declaratively; **removal is always manual** (edit the file). The
invariant is enforced everywhere: **paths are unique, remotes may repeat** (the same remote
cloned to two paths is fine; the same path twice is not).

- **`den clone sync [--dry]`** (`cmd/clone.sh` → `den-helper clone-plan`) — scan the bound
  tree for every git work tree (incl. nested, via `_clones_scan_json`) and **upsert**: a
  repo whose path is new is appended (even if its remote already exists elsewhere); a path
  already registered with the **same** remote is a no-op; a path registered with a
  **different** remote is a **conflict** (reported, never auto-changed — fix by editing the
  repo's remote or `clones.json`); a present repo with **no origin**, or a `clones.json`
  entry that **lacks a remote** whose path is present, is a **no-remote** error. Conflicts +
  no-remote are shown in bulk and exit non-zero; the non-conflicting adds still apply
  (partial sync). `--dry` reports the same plan without writing.
- **`den clone drift`** — non-mutating report of `clones.json` vs disk: **untracked** (repo
  on disk, not registered → `den clone sync`), **missing** (registered, not cloned here →
  `den bootstrap`), **remote-drift**, **no-remote**.
- **`den bootstrap`** (`cmd/bootstrap.sh`) — read-only, **reconcile-to-actions** (not just a
  scratch-setup command — run it any time cwd drifts from `clones.json`, e.g. after another
  host adds a clone). Prints **only the actionable differences**: `git clone <remote> <path>`
  when the path is **missing or an empty dir** and has a remote; `mkdir -p <path>` when the
  entry has **no remote**; warnings (stderr, left untouched) for a path that is **non-empty
  with a different origin** or **non-empty and not a git repo**. A `den pull` line is printed
  **only** when it would do something — after any clone/mkdir, or when there is
  **pullable drift** (missing-link files whose owning clone is already present + matching, or
  root/non-clone files). If nothing differs it prints `nothing to do — cwd matches this
  project.`. Skips `.` (the binding root is already present).

## Hide (`den hide`) — git-exclude a path without tracking it

`den add` solves "hide *and* version-control this file". `den hide` solves the
other half: **hide a path from a foreign repo's `git status` without moving it
into the vault** — for locally-generated artifacts (a tool's `.claude/` dir,
a build cache, an IDE folder) you never want committed to the corporate remote
*and* never want pushed into your Notes vault either.

**`.denhidden` is the source of truth** — a gitignore-syntax file in the project
dir (Notes-side → travels), patterns interpreted **relative to the binding
root**. den never mutates `info/exclude` ad-hoc; it **reconciles** each repo's
`info/exclude` to match `.denhidden` on every `den pull` (and after
`hide`/`unhide`). Mechanism (`lib/guard.sh` + `helper/cmd/hidden.py`):

- **`den hide <path|pattern>...`** (`cmd/hide.sh` → `_do_hide`) — resolves each
  arg **cwd-relative** via `_rel_under_root` (so `den hide .claude` from a subdir
  targets *that* subdir's `.claude`), appends it to `.denhidden` as a
  **root-anchored pattern** (`/legacy/bdsi/.claude` — so only that one location
  is excluded, and a nested `.claude` never collides with a root-level one),
  records the containing clone (`_hidden_record_clone_for`) for host-2, then runs
  the reconcile. A quoted glob (`den hide '*.log'`) is anchored under your cwd.
  For repo-wide/unanchored patterns, hand-edit `.denhidden` (e.g. add `*.log` or
  `build/`) — `den pull` reconciles them identically.
- **`den unhide <path|pattern>...`** (`cmd/unhide.sh`) — drops the matching line
  from `.denhidden` (tries both the exact string and the resolved `/rel` form),
  then reconciles. The path reappears in `git status`.
- **The reconcile** (`_hidden_reassert_all`): `den-helper hidden-plan` maps each
  `.denhidden` pattern to the repo it applies to (root repo `.` or a registered
  clone) and re-anchors it into that repo's frame — a nested clone is a *separate*
  gitignore scope, so a root-level `*.log` does **not** reach inside it. For every
  present repo (root + each registered clone), den rewrites a `# BEGIN/END
  den-hidden` **managed block** in its `.git/info/exclude` to exactly the mapped
  lines (empty → block removed). Your own non-block lines in `info/exclude` are
  preserved; stale den lines are dropped. Idempotent, declarative.
- **Cross-host**: host-2 pulls the vault (carrying `.denhidden` + `clones.json`),
  `git clone` the repos den reports, `den pull` → blocks reconciled for every
  repo present.
- **`den ls`** shows a `hidden (git-excluded, not tracked):` section listing the
  `.denhidden` patterns (scope-filtered, leading `/` stripped for the match).
- **`den doctor`** `[HIDE]` check: for each present repo, recomputes the expected
  managed block from `.denhidden` and compares it to the one in `info/exclude`;
  any mismatch counts toward the non-zero exit (fix: `den pull`).
- **Cross-project seeding**: `den new <NEW> --from <EXISTING>` and `den sync
  <OTHER>` copy `.denhidden` **and** `clones.json` alongside
  `files/`/`.denignore`/`hooks/`, so a project spun up from another starts with
  the same hide + clone registries (then `den pull` reconciles). Neither carries
  `patches/`/`.activity/`.

Both `.denhidden` and `.denignore` are **full gitignore syntax** (`**`, `!`
negation, `/`-anchoring, `[...]`, trailing-`/`) — `.denignore` via the `pathspec`
matcher in the walker, `.denhidden` because its patterns are forwarded verbatim
into git's own `info/exclude` (which *is* gitignore).

Contrast the three "keep it out of the foreign repo" tools:

| Command | Moves file into vault `files/`? | Edits foreign `.git/info/exclude`? | Cross-host record |
|---|---|---|---|
| `den add` | yes (symlink/hardlink back) | yes (auto-guard) | `clones.json` + `files/` |
| `den hide` | **no** | yes | `.denhidden` |
| `den ignore` | no | **no** (den-internal only) | `.denignore` (den's own walk) |

`den ignore` marks a path host-only for **den's** drift accounting — it does NOT
touch git, so the path still shows in the foreign repo's `git status`. Use
`den hide` when the goal is a clean `git status` in a repo you don't own.

## Archived (hidden) projects

Archive is a convention on the **immediate children of `projects/` only**. A project
dir (a single flat name directly under `Notes/projects/`) whose name starts with `.` is
**archived** — invisible to den. Rename `Notes/projects/foo` → `Notes/projects/.foo` to
shelve / back it up without deleting it; rename it back to restore. `projects/.dirA`
archives dirA and everything under it.

**This never applies inside a project.** `projects/dirA/dirB` or a pushed
`projects/dirA/files/.env` / `.claude/` is real, den-tracked content — the file walker
(`helper/lib/manifest.py:_walk_files`) deliberately walks dotfiles. You can only archive
by dotting the top-level project dir itself; there is no per-file archive.

`lib/meta.sh:_project_name_is_archived` is the sole predicate and takes a **bare project
name** (returns false for anything containing `/`, so it can't be tricked by a path);
`_reject_hidden_project` aborts (exit 2) on a `.`-prefixed name. Enforced at every
surface: `den list` reduces each `$DEN_PROJECTS/*/` entry (one level) to its basename and
skips dot-names in both JSON + plain loops — so `den init` fzf and shell completion, which
read `den list`, never surface them; `den new`/`new --from`/`init`/`sync <OTHER>` reject
dot-names; `_scaffold_project` refuses to create one (den never emits a dot-prefixed name).
Note: if you archive the project a cwd is currently bound to, commands in that cwd
(`status`/`pull`) hit "project source missing" — archived-away behavior, not a bug;
un-archive or `den clean` the binding.

## Destructive `den rm` gate

`den rm <path>...` is destructive (drops symlink + guard + `files/<rel>` + ledger). It now
**refuses unless every selected target is committed + clean in the Notes vault** — so the
content is recoverable from git before it's thrown away. `lib/meta.sh:_notes_path_committed`
checks *per selected path* (not the whole vault): tracked by git **and** `git status
--porcelain -- <path>` empty. "Nothing to push" is interpreted as **working-tree clean**
(local commits are assumed pushed regularly; the remote is not probed). `-f`/`--force`
overrides the gate **and** skips the confirm prompt; `--yes`/`-y` skips only the prompt
(gate still enforced). If Notes isn't a git repo the gate is a no-op.

## Shelf (`den shelf`) — git-stash-like file sets

A per-project stack for temporarily removing den files and swapping them back — e.g.
keeping one of several `.env` variants live at a time. Distinct from `den stash` (a git
*patch-series* carrier that needs a git repo and is for WIP diffs). Storage:
`<project>/archive/<ns>/` per row (`ns` = `date +%s%N`, sortable + unique), each with
`manifest.json` (`{name, created_at, host, files:[{rel,kind}]}`) + the moved `files/`. Rows
live in the Notes vault, so they're version-controlled and cross-host.

- **`den shelf add <paths>|. [--name N]`** — one invocation = one ROW. Resolves args to
  den-managed rels via the ledger (`_shelf_resolve_targets`): a dir / `.` expands to every
  ledger target **at or under** it (cwd + nested, never parent), a file matches only if it's
  a ledger target. Each matched file is **removed git-stash-style**: symlink dropped, guard
  dropped (`_guard_unlink`), `files/<rel>` **moved** into the row, ledger entry cleared.
  Prompts for a non-blank name (dup names allowed — the row dir's timestamp disambiguates;
  `--name` skips the prompt, required non-interactively).
- **`den shelf`** (bare) / **`list`** — rows newest-first, ids like `git stash` (0 = newest,
  recomputed each call), through `$PAGER`.
- **`den shelf apply [id]`** — **COPY** the row's files back to their sites; row + archive
  content kept. **`den shelf pop [id]`** — **MOVE** them back; applied files leave the row,
  and the row is deleted once empty. Default id = top row.
- **conflicts (all-or-nothing)**: apply/pop run a pre-flight scan of the whole row first — if
  ANY target site is occupied (live symlink or real file) or its archived content is missing,
  the op **aborts and touches nothing**, listing the offending paths. Never partial. Free the
  occupant(s) (shelf them), then re-apply/pop. Restored files are re-guarded + re-added to the
  ledger.
- **`den shelf drop <id>`** — delete one row. **`den shelf clear [-f]`** — wipe the whole
  `archive/`, gated on the archive being committed+clean in Notes; `-f` overrides.

## Dev-shell bootstrap (`den new --devshell`)

`den new` can seed a project with a Nix dev shell from `the-nix-way/dev-templates` (~40 languages: python, go, rust, node, java, …). The template source is pinned as the `dev-templates` flake input and exposed to the bash CLI as `$DEN_DEV_TEMPLATES_DIR`.

Three flag shapes:

| Invocation | Behavior |
|---|---|
| `den new myproj --devshell python` | Non-interactive. Copies `$DEN_DEV_TEMPLATES_DIR/python/*` into `Notes/projects/myproj/files/`, hardlinks `flake.nix` (and `flake.lock` if present), writes `.envrc` (`use flake`), appends `.direnv/` to `.denignore`. |
| `den new myproj --no-devshell` | Non-interactive. Skip — identical to pre-feature behavior. |
| `den new myproj` (TTY) | Prompts "Bootstrap a Nix dev shell? [y/N]". On yes, fzf (or numbered `select`) picker over `_devshell_list`. |
| `den new myproj` (non-TTY) | Skips silently — preserves CI/script behavior. |

After the post-`new` `_do_pull` materializes the symlinks/hardlinks, `_devshell_post_pull` runs `direnv allow` in the bound cwd on TTY, or prints a hint otherwise. Skipped if no `.envrc` was written.

**Why hardlink `flake.nix`/`flake.lock`** — nix copies the project source to `/nix/store/.../source/` before evaluating the flake, then mis-resolves absolute symlink targets relative to that copy (e.g. `path '/nix/store/.../source/home/.../files/flake.nix' does not exist`). Hardlinking makes the file appear as a real file on both sides while still sharing an inode with the project source — `nix develop` works, edits in either place reflect in the other. Editor atomic-saves break the inode link; `den status` flags as `replaced-with-real-file` and `den re-add <path>` rebuilds it.

**Why `.envrc` stays a symlink** — direnv evaluates `.envrc` in cwd as a shell script; it doesn't pass paths to nix, so the absolute-symlink-out-of-tree gotcha doesn't apply.

**`claude-kit.nix` sibling** — `_devshell_apply` also drops `claude-kit.nix` next to `flake.nix` (copied from `$DEN_CLAUDEKIT_SHIM/claude-kit.nix`). Pure attrset schema for project-scoped Claude resources (`envVars` / `skills` / `agents` / `commands` / `plugins` / `mcp`). The `.envrc` written from `$DEN_CLAUDEKIT_SHIM/envrc` runs `claude-kit project envrc` (exports non-empty envVars; empty entries fall through to host env) and `claude-kit project sync --quiet` (reconciles `./.claude/` + `./.mcp.json`) on every direnv reload. Both files are copied write-once, so user edits to either survive subsequent `den new` runs against the same project dir. `.claude/.flake-managed.json` is auto-appended to `.denignore` so the sync state stays out of project history. Inside a den project the `claude-kit lazy add/rm` and `lazy bundle add/rm` mutators auto-route through `claude-kit.nix` (`_lazy_find_project_config` walks upward, `_project_edit_list` rewrites the matching top-level list) so the declarative file stays authoritative — pass `--imperative` to fall back to direct `./.claude/` edits, or hand-edit the file and re-run `direnv reload`.

**To bump the template set**: `nix flake lock --update-input dev-templates` then `nix_switch`. Existing projects keep their pinned `flake.lock` (lives in `Notes/projects/<N>/files/`); only newly-created projects pick up template-side changes.

## Integration

Imported by `../default.nix` as `./den` (resolves to this `default.nix`). Linux-only — the entire `config` block is gated on `pkgs.stdenv.isLinux`. See `../CLAUDE.md` → `## den` for the full feature surface (binding lifecycle, presets, hooks, patches CAS, generations, reflog, layered config, doctor invariants, prompt block).

