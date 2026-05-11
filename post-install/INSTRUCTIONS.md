# killuanix post-install runbook

Manual setup steps that cannot be expressed declaratively in the flake.
Each `- [ ]` item carries a stable ID in an HTML comment that matches a
script under `post-install/steps/`. The dispatcher is `./post-install/run.sh`.

**For solo use:** read the file, do the steps, optionally invoke
`./post-install/run.sh do <id>` for the steps that have helper logic.

**For Claude Code use:** feed this file to a session and ask "walk me
through post-install starting at step X". Claude reads the IDs and
proposes `./run.sh do <id>` invocations. Sentinels at
`$XDG_STATE_HOME/killuanix-postinstall/<host>/<id>.done` keep already-done
steps from re-running.

## Day 0 — fresh NixOS install

You only have **internet, git, curl, terminal**. The flake is not yet
applied; `scripts/nix_switch` does not exist yet. Run these literal
commands:

```bash
# 1. Clone the repo (no submodules — Notes/DotFiles/aconfmgr are private)
curl -fsSL https://raw.githubusercontent.com/Killua7362/killuanix/master/post-install/bootstrap.sh | bash
cd ~/killuanix

# 2. Replace the host's hardware config with the freshly-generated one
HOST=$(hostname -s)                # chrollo or killua
cp /etc/nixos/hardware-configuration.nix "$HOST/hardware-configuration.nix"
# Or via the runbook:
#   ./post-install/run.sh do 05-hardware-config

# 3. Get the ssh-ed25519 private key from Bitwarden (web vault works fine
#    on a fresh machine — vault.bitwarden.com). Save it to a tmp file.
#    Then convert it into an age key:
./post-install/convert-ssh-to-age.sh /tmp/sshkey
shred -u /tmp/sshkey 2>/dev/null || rm -f /tmp/sshkey
# The converter self-bootstraps `ssh-to-age` via `nix shell nixpkgs#ssh-to-age`,
# so it runs even on a stock NixOS install with nothing extra installed.

# 4. Verify sops can decrypt with the new age key (read-only)
nix run --extra-experimental-features 'nix-command flakes' \
  nixpkgs#sops -- -d secrets/personal.yaml >/dev/null && echo OK

# 5. First system build — `scripts/nix_switch` is not on PATH yet, so
#    invoke nixos-rebuild directly:
sudo nixos-rebuild switch --flake .#$HOST

# 6. First home-manager build — home-manager CLI is not on PATH yet,
#    so run it via `nix run`:
nix run --extra-experimental-features 'nix-command flakes' \
  home-manager/master -- switch --flake .#$HOST
```

After step 6, `scripts/nix_switch`, `home-manager`, and the rest of the
flake are available. From then on, use `scripts/nix_switch` for normal
rebuilds.

## Sentinel checklist

Steps below have helper scripts under `steps/`. Sentinel state at
`$XDG_STATE_HOME/killuanix-postinstall/<host>/<id>.done` keeps them
idempotent across re-runs.

### Critical first (run during Day 0 above)

- [ ] Copy hardware-configuration.nix into the host dir <!-- id:05-hardware-config -->
  - Diffs `/etc/nixos/hardware-configuration.nix` against the committed file, prompts before overwriting.

- [ ] Bootstrap sops age key <!-- id:00-age-key -->
  - Default option: convert ssh-ed25519 private key (Bitwarden) via `convert-ssh-to-age.sh`. Other options: paste raw age key, scp from another host, read from a `bw` note.
  - Refuses to overwrite an existing non-empty key without `FORCE=1`.
  - Test mode: `SOPS_AGE_KEY_FILE=/tmp/keys-test.txt ./run.sh do 00-age-key` writes to a temp path, never touches the real key.

- [ ] Verify sops decrypts cleanly (read-only) <!-- id:01-sops-verify -->
  - Runs `sops -d secrets/personal.yaml >/dev/null` against the configured key. Read-only — never modifies the key.
  - If this passes, the first `nixos-rebuild switch` should be safe.

## After first switch

After `nixos-rebuild` + `home-manager switch` complete, container
services exist and the rest of the runbook applies.

- [ ] Bitwarden CLI login + unlock <!-- id:10-bitwarden -->
  - Required only if you want `00-age-key` option 3 to work, or use `bw` in scripts. Desktop + Firefox extension unlock separately.

- [ ] Firefox Sync + Bitwarden extension master pw <!-- id:11-firefox-sync -->
  - Opens `about:preferences#sync`. Sign in, wait for sync, unlock the extension.

- [ ] SSH keys <!-- id:30-ssh-keys -->
  - Paste an existing private key, generate a fresh ed25519, or skip. **Never overwrites an existing `~/.ssh/id_ed25519`**.
  - Public key is printed at the end — register on GitHub/GitLab/servers.

- [ ] Linkding admin login + API token <!-- id:20-linkding -->
  - Admin user is auto-created from sops; you log in to grab the token for the browser extension.

- [ ] Cronicle: change default admin password <!-- id:21-cronicle -->
  - Default `admin/admin` — change before exposing anywhere.

- [ ] Thunderbird account wizard <!-- id:40-thunderbird -->
  - Mail accounts are not declarative; configure once per host.

## Project-specific

- [ ] Boeing modernization local infra <!-- id:22-boeing -->
  - Requires `~/Documents/Boeing/modernization/` cloned with worktrees. Runs `just up`, smoke-checks `:8181` (mongo-express) and `:8281` (redis-commander).

## Host-specific

- [ ] killua handheld (MSI Claw) bits <!-- id:90-host-killua -->
  - Steam, hhd-ui, Decky. Auto-skips on other hosts.

## Operator cheatsheet

```bash
./run.sh list              # status of every step on this host
./run.sh do <id>           # run one
./run.sh all               # run every step in numeric order, skip done
./run.sh reset <id>        # clear sentinel so step re-runs
./run.sh reset-all         # clear all sentinels (asks first)
DRY_RUN=1 ./run.sh do <id> # echo what would happen, change nothing
```

State lives at `$XDG_STATE_HOME/killuanix-postinstall/<host>/`. Hostname
namespacing lets the same checkout track chrollo + killua independently.

## Adding a new step

1. Drop a new `steps/NN-name.sh` defining a `run()` function. Numeric
   prefix sets execution order (`00-`, `10-`, `20-`...).
2. Source `lib/common.sh` helpers via the parent `run.sh` (your script
   doesn't need to re-source — it inherits the env when invoked through
   `run_step`).
3. Add a `- [ ] ... <!-- id:NN-name -->` line in this file.
4. Test: `DRY_RUN=1 ./run.sh do NN-name` then real run.

Helpers available inside `run()`: `log`, `ok`, `warn`, `err`, `hint`,
`has_cmd`, `confirm`, `dry`. State paths: `$REPO_ROOT`, `$STATE_DIR`,
`$HOSTNAME_SHORT`, `$SOPS_AGE_KEY_FILE` (if set).

Safety rules baked into helpers:
- Never silently overwrite a non-empty credential file.
- `confirm` always defaults to N.
- `DRY_RUN=1` short-circuits every state-changing branch.
