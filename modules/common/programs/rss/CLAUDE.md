# RSS Module

Home Manager module for the desktop RSS reader (RSSGuard), paired with the
local FreshRSS container at `modules/containers/freshrss/`.

## Files

| File | Description |
|---|---|
| `default.nix` | Imports the rssguard config + (no-op-when-disabled) account-seed service. |
| `rssguard.nix` | Installs `pkgs.rssguard` and renders `~/.config/RSS Guard 4/config/config.ini` (yes, with spaces — that's the actual AppName) from a nix attrset via `lib.generators.toINI`. Linux-only. |
| `account-seed.nix` | Optional systemd-user oneshot that INSERTs a FreshRSS greader account row into RSSGuard's SQLite DB so the first launch is fully wired. Off by default. |

## How config.ini works

The INI file is a **read-only symlink into the nix store**. Any "Save
settings" click in RSSGuard's preferences dialog silently fails to persist
for keys we manage here — same gotcha as `ccmanager`'s
`~/.config/ccmanager/config.json`. To change a managed setting, edit
`rssguard.nix` and re-`nix_switch`.

Volatile keys we deliberately **do not** set so RSSGuard can keep writing
them to its own (mutable) state:

- `gui/window_size`, `gui/window_position`, `gui/window_is_maximized`
- `gui/splitter_*`, `gui/feed_view_state`, `gui/msg_view_state` (Qt-serialized
  `QByteArray` blobs — not safe to hand-author)
- `categories_expand_states/*` (per-category expand/collapse memory)

These live in the same `config.ini` file at runtime; QSettings is fine with
the merge because we never write the file with those keys, and Qt only
overwrites the keys we DID write.

⚠️ Caveat: because the file is a store symlink, Qt cannot edit it in place.
On the first save attempt Qt will **replace the symlink with a real file**
copying the nix-store content + its new edits. After that, nix-store changes
won't propagate until the user clears the file. If this becomes a problem,
switch to `home.activation` writing the file with `install -m 644` instead
of `xdg.configFile`.

Section names must be **lowercase** (`[gui]`, not `[GUI]`) — Qt's QSettings
canonicalizes them on write, and reading from `[GUI]` returns nothing.
Confirmed against upstream `src/librssguard/miscellaneous/settings.cpp`.

## Account-seed flow (opt-in)

Enable by editing `account-seed.nix`:

```nix
cfg = {
  enable = true;
  mode = "schema-only";
  url = "http://localhost:8083/api/greader.php/";
  username = "killua";
  service = 1;          # FreshRSS
  batchSize = 100;
  ...
};
```

On the next `home-manager switch` a `rssguard-account-seed.path` unit is
enabled. It watches `~/.config/RSS Guard 4/database/database.db` (yes, with
spaces — that's RSSGuard's actual `AppName` and what `QStandardPaths` resolves
to) and triggers
`rssguard-account-seed.service` the moment the file appears — i.e. the user's
first real RSSGuard launch. The service is gated by
`$XDG_STATE_HOME/rssguard4/.account-seeded` so it runs at most once per host:

1. Bails out if the sentinel exists, or if no DB yet (path unit will refire).
2. Bails out cleanly if an account row for the same URL already exists.
3. Otherwise INSERTs `Accounts (ordr, type, proxy_type, custom_data) VALUES
   (1, 'greader', 0, '<json>')` with `password = ""`. On the next GUI launch
   RSSGuard prompts for the FreshRSS API password and stores its own
   SimpleCrypt-encrypted ciphertext.

We use a path unit (not a oneshot at activation) because RSSGuard 4.8.6's
`--version` flag exits before `Application::userDataHomeFolder()` initializes
the data dir, so we cannot pre-create the DB headlessly. The user must
launch RSSGuard once; the seed then runs automatically the same second.

### Why no `mode = "with-password"`

RSSGuard encrypts saved account passwords with a per-install
`~/.config/RSS Guard 4/config/key.private` (random `quint64`, generated on
first launch). We cannot pre-compute the ciphertext at flake-build time. A
fully-zero-click path would need a vendored `simplecrypt.cc` helper built
with `pkgs.runCommandCC` that reads `key.private` + the API password from
sops and emits the ciphertext at activation. The complexity didn't justify
saving the user one password paste, so only schema-only is implemented. The
`assertions` block enforces this.

## CLI reality check

RSSGuard's full flag list (`application.cpp:1269-1309` upstream): `-h`,
`-v`, `-d <data-dir>`, `-s` (no-single-instance), `-g` (debug),
`--force-text-browser`, `-l <log-file>`, `-t <style>`, `-u <user-agent>`,
`--threads <count>`, positional URLs. **There is no OPML-import flag, no
account-add flag, no headless mode.** That's why we go through SQLite
directly for declarative account seeding.

## Skins

The package ships `minimal-light`, `minimal-dark`, `minimal-base`. To install
a custom skin from a flake input or local path:

```nix
xdg.configFile."RSS Guard 4/skins/my-skin".source = ./skins/my-skin;
```

Then set `gui.skin = "my-skin"` in `rssguard.nix`. A valid skin folder needs
at minimum `metadata.xml`, `qt_style.qss`, `html_wrapper.html`, and
`html_single_message.html`.

## Integration

Imported from `modules/cross-platform/default.nix` so the config lands on
every Linux home (`chrollo`, `killua`, `archnix`). macOS skips it via the
`lib.mkIf pkgs.stdenv.isLinux` guard in `rssguard.nix`. The matching server
side is `modules/containers/freshrss/` on `chrollo` + `killua`. `archnix`
won't have a local FreshRSS server unless you point `account-seed.nix` at a
remote one.
