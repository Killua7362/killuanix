# post-install/

Self-contained runbook + helpers for the irreducibly-manual bits of
bringing up a fresh killuanix host. Not referenced from the root
`CLAUDE.md` on purpose — feed `INSTRUCTIONS.md` to Claude only when you
want a guided walkthrough.

## Fresh NixOS install — one-liner

Stock NixOS box with only internet + `git` + `curl` + bash:

```bash
curl -fsSL https://raw.githubusercontent.com/Killua7362/killuanix/master/post-install/bootstrap.sh | bash
```

Clones `https://github.com/Killua7362/killuanix.git` to `~/killuanix`
**without submodules** (Notes / DotFiles / aconfmgr are private and need
a GitHub token), then prints Day 0 next-steps. Override destination with
`KILLUANIX_DIR=$HOME/somewhere bash`.

After cloning, follow the **Day 0** section in
[INSTRUCTIONS.md](INSTRUCTIONS.md): copy hardware config, convert ssh
key → age key, verify sops, run `nixos-rebuild switch` and
`nix run home-manager/master -- switch`.

## Standalone helpers (callable directly, not via `run.sh`)

```bash
# Convert an OpenSSH ed25519 private key into an age key.
# Self-bootstraps ssh-to-age via `nix shell nixpkgs#ssh-to-age` if needed.
./post-install/convert-ssh-to-age.sh /path/to/ssh/private/key
./post-install/convert-ssh-to-age.sh -          # read key from stdin
SOPS_AGE_KEY_FILE=/tmp/test.txt \
  ./post-install/convert-ssh-to-age.sh ~/key    # write to temp path (testing)
```

The converter never overwrites a non-empty existing key file without
`FORCE=1` + interactive confirm.

## Use it solo

```bash
cd ~/killuanix/post-install
./run.sh list                     # see what's done on this host
./run.sh do 00-age-key            # run a single step
./run.sh all                      # run every step, skipping ones already done
DRY_RUN=1 ./run.sh do 00-age-key  # echo the actions, change nothing
```

Read `INSTRUCTIONS.md` top to bottom — every checkbox has a stable ID
that maps to a script under `steps/`.

## Use it with Claude

Open a Claude Code session and paste:

> Read `~/killuanix/post-install/INSTRUCTIONS.md` and walk me through
> post-install for `<hostname>`. Run `./run.sh list` first to see what's
> already done.

Claude can invoke `./run.sh do <id>` via Bash. Sentinels (per-host)
prevent re-running completed steps. The dispatcher accepts `DRY_RUN=1`
when you want Claude to show its work without changing the system.

## Layout

```
post-install/
├── INSTRUCTIONS.md           GFM checklist with stable IDs (the runbook)
├── README.md                 this file
├── bootstrap.sh              curl|bash entry; clones repo on a fresh box
├── convert-ssh-to-age.sh     ssh-ed25519 -> age key (self-bootstraps ssh-to-age)
├── run.sh                    list / do / all / reset / reset-all / DRY_RUN
├── lib/common.sh             log, confirm, has_cmd, sentinel helpers
└── steps/NN-*.sh             one script per step; defines a run() function
```

State directory: `$XDG_STATE_HOME/killuanix-postinstall/<host>/<id>.done`

## Safety invariants

- **Never deletes the live sops age key.** `00-age-key` refuses to
  overwrite an existing key without `FORCE=1` + interactive confirm.
- **Never overwrites an existing SSH private key.** `30-ssh-keys` only
  generates if `~/.ssh/id_ed25519` is missing.
- **`confirm` defaults to N.** A blank Enter is "no".
- **`DRY_RUN=1` short-circuits state-changing branches** in every helper
  that touches the filesystem.

## Adding a step

1. Drop `steps/NN-name.sh` with a `run()` function. Numeric prefix sets
   execution order.
2. Add a `- [ ] ... <!-- id:NN-name -->` line in `INSTRUCTIONS.md`.
3. Test with `DRY_RUN=1` first.

Helpers available inside `run()`: `log`, `ok`, `warn`, `err`, `hint`,
`has_cmd`, `confirm`, `dry`. Useful vars: `$REPO_ROOT`, `$STATE_DIR`,
`$HOSTNAME_SHORT`.
