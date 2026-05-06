# den

`den` — project-scoped symlink + patch manager. A bash CLI (`den`) that binds named projects under `Notes/projects/<NAME>/` to working directories via symlinks, plus a Python sidecar (`den-helper`) that handles the heavy ops (tree-walk, manifest hashing, JSONL ops, drift status, TOML I/O).

Originally a single 2944-line `den.nix` with a `writeShellApplication` body and an inlined `writers.writePython3Bin` body. Split into a directory so each subcommand lives in its own file with a real LSP and shellcheck/pyright. Behavior is unchanged — both bodies are wired to the same wrapper that the `den` and `den-helper` packages always shipped.

## Files

| File | Description |
|---|---|
| `default.nix` | HM module — declares `programs.den` options, builds the bash + python packages, wires shared/host overlay, completions, and the optional starship block. The bash wrapper exec's `bash $DEN_LIB_DIR/den.sh "$@"`; `den-helper` is a tiny entry stub that adds `helper/` to `sys.path` and calls `main()`. |
| `scripts/den.sh` | Bash entrypoint. Sets globals (`DEN_NOTES`, `DEN_PROJECTS`, `DEN_STATE`, `DEN_HOST`, `DEN_BINDINGS`, etc.), sources every `lib/*.sh` and `cmd/*.sh`, then dispatches `$1` to `den_cmd_<name>`. Falls back to `den-<name>` on PATH for git-style external subcommands. |
| `scripts/lib/common.sh` | Error template (`_err`/`_die`/`_warn`/`_info`), tty + yes/no helpers, `_find_binding_root`, `_resolve_target_path`, `_with_lock` (flock 9), `_maybe_zoxide_add`. |
| `scripts/lib/meta.sh` | `.den-meta.json` helpers (`_meta_path`/`_meta_init`/`_meta_get`/`_meta_ensure_keys`/`_meta_update`), `_project_dir_for`, `_require_bound`, activity-log + `lastop` + reflog writers, `_scaffold_project` (presets `bare`, `minimal`, `claude-full`). |
| `scripts/lib/manifest.sh` | `manifest.toml` helpers — `_load_manifest_kinds` (returns JSON `{rel: kind}`), `_kind_for_rel`, `_set_manifest_kind` (insert/update/remove an entry; setting kind="symlink" deletes the override since symlink is the default), `_link_for_kind` (creates symlink or hardlink, errors on cross-fs hardlink). |
| `scripts/lib/bindings.sh` | Per-host bindings registry (`$DEN_BINDINGS`) — `_bindings_{init,add,remove,list_for,owner,prune}`. Powers `den cd` / `den which`. |
| `scripts/lib/store.sh` | Content-addressed store (CAS) at `$DEN_CAS_ROOT` — `_cas_{init,path_for,put,get,has,record_ref,record_anchor,anchor_lookup,restore_to_git}`. Used by `den stash` (anchor-blob capture) and `den apply` (3-way merge recovery). |
| `scripts/lib/hooks.sh` | `_run_hook` — dispatches lifecycle events (pre/post-pull/clean/add/sync/stash/apply) to shared (Notes-side) and host-overlay hooks; host hooks must be SHA-trusted via `den hooks trust <event>`. |
| `scripts/lib/generations.sh` | `_gen_dir`, `_write_generation` — per-cwd snapshots under `<root>/.den-generations/`. |
| `scripts/lib/devshell.sh` | `_devshell_{list,pick_interactive,resolve,apply,post_pull}` — bootstrap a `the-nix-way/dev-templates` flake into a new project's `files/` and wire it for `nix-direnv`. Used only by `cmd/new.sh`. Reads `$DEN_DEV_TEMPLATES_DIR` (set by the wrapper from the `dev-templates` flake input). |
| `scripts/cmd/<name>.sh` | One file per subcommand. Each defines `den_cmd_<name>` (and any private `_do_<name>` helpers). Exact subcommand set (matches the original dispatcher in `den.sh`): `help`, `version` + `explain` (in `help.sh`), `list`, `ls`, `status`, `new`, `init`, `clean`, `pull`, `replicate`, `add`, `ignore`, `rm`, `re-add`, `restore`, `sync`, `stash`, `apply`, `patches`, `which`, `cd`, `exec`, `activate`, `prompt`, `log`, `last-applied`, `reflog`, `generations`, `rollback`, `diff`, `gc`, `cas`, `config`, `hooks`, `doctor`, `completion`. |
| `helper/main.py` | argparse dispatcher for `den-helper`. Subcommands: `walk`, `manifest-hash`, `status`, `render-status`, `append-jsonl`, `read-jsonl`, `parse-toml`, `write-toml`. |
| `helper/lib/toml_io.py` | Minimal flat-table TOML serializer + `tomllib`/`tomli` re-export. |
| `helper/lib/ignore.py` | `.denignore` parser + gitignore-style matcher. |
| `helper/lib/manifest.py` | Sorted recursive `_walk_files` and `_sha256_file`. |
| `helper/cmd/walk.py` | `walk` — list files under `--root`. |
| `helper/cmd/manifest_hash.py` | `manifest-hash` — sha256 over (path, content-sha) pairs of `<root>/files/`. |
| `helper/cmd/status.py` | `status` (5-bucket drift compute) + `render-status` (pretty-print, exit 1 on drift). |
| `helper/cmd/jsonl.py` | `append-jsonl` (auto-stamps `ts`) + `read-jsonl` (with `--tail`). |
| `helper/cmd/toml.py` | `parse-toml` → JSON; `write-toml` ← JSON on stdin. |

## Env-var contract

The bash wrapper in `default.nix` exports two paths and exec's `bash $DEN_LIB_DIR/den.sh "$@"`. Everything else is read by the bash from the user's environment (`HOSTNAME`, `XDG_DATA_HOME`, `XDG_CONFIG_HOME`, `EDITOR`, `DEN_NOTES`, etc.) with sensible defaults.

| Variable | Set by | Purpose |
|---|---|---|
| `DEN_LIB_DIR` | wrapper | Store path of the `den-scripts` derivation; `den.sh` sources `$DEN_LIB_DIR/{lib,cmd}/*.sh` from here. |
| `DEN_HELPER_BIN` | wrapper | Absolute path of the `den-helper` binary. Bash always invokes the helper as `"$DEN_HELPER_BIN" <subcmd>` — never relies on PATH so it survives a stripped environment. |
| `DEN_NOTES` | `home.sessionVariables` | Notes-vault path; defaults in bash to `$HOME/killuanix/Notes` if unset. |
| `DEN_DEV_TEMPLATES_DIR` | wrapper | Store path of the pinned `the-nix-way/dev-templates` flake input. `den new --devshell <lang>` (and the interactive picker) read template subdirs from here. Bumped by `nix flake lock --update-input dev-templates`. |

**Do not** add `${...}` Nix interpolation inside `.sh` or `.py` files. Pass any new nix-injected value as another `export VAR=...` line in the `text` block of `default.nix`.

## How to add a new subcommand

1. Drop `scripts/cmd/<name>.sh` defining `den_cmd_<name>` (use `_<name>_helper` for private helpers — every `_*` is sourced into the same shell, so name collisions matter).
2. Add a `case` arm in `scripts/den.sh` dispatching `<name>) den_cmd_<name> "$@";;`.
3. Update the help text in `scripts/cmd/help.sh` and the completion lists in `scripts/cmd/completion.sh` (bash + zsh + fish, all hard-coded).
4. If it shells out to the python helper, also add a parser to `helper/main.py` and a `cmd_<name>` in `helper/cmd/<name>.py`. The library helpers under `helper/lib/` are import-only — keep `cmd_*` thin.

For an external `den-foo` git-style subcommand, just put the executable on PATH and call `den foo`; the dispatcher's `_try_external_subcommand` fallback exec's into it.

## `den replicate` (wt-sibling worktrees)

`den replicate [--source <dir>] <target>` re-creates the source binding's
symlinks/hardlinks (read from `<source>/.den-meta.json` `.symlinks` ledger
and `<project>/manifest.toml` for kind overrides) inside `<target>` at the
same relative paths. Skips entries that already exist in `<target>` so a
worktree's git-checked-out files are left alone. **Does not** register
`<target>` as a binding — no `.den-meta.json` is written there. Used by
`scripts/wt`'s `wt new` to seed a fresh sibling worktree with the
den-managed files (CLAUDE.md, etc.) that live in `main/` but aren't tracked
by git.

Hardlinks deliberately share an inode with the project source, so an edit
in any worktree's hardlinked file flows back to the project copy and to
every other binding/worktree pointing at it. The command emits a stderr
warning when any hardlinks are created. Users who want full den semantics
(its own `.den-meta.json`, drift status, hooks) in a worktree should run
`den new`/`den init` themselves — `replicate` is a one-shot copy.

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

**To bump the template set**: `nix flake lock --update-input dev-templates` then `nix_switch`. Existing projects keep their pinned `flake.lock` (lives in `Notes/projects/<N>/files/`); only newly-created projects pick up template-side changes.

## Integration

Imported by `../default.nix` as `./den` (resolves to this `default.nix`). Linux-only — the entire `config` block is gated on `pkgs.stdenv.isLinux`. See `../CLAUDE.md` → `## den` for the full feature surface (binding lifecycle, presets, hooks, patches CAS, generations, reflog, layered config, doctor invariants, prompt block).

