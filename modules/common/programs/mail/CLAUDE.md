# Mail Module

Home Manager module for declarative email clients. Currently just Thunderbird.

## Files

| File | Description |
|---|---|
| `default.nix` | Entry point; imports `./thunderbird.nix` |
| `thunderbird.nix` | Thunderbird config with a power-user add-on bundle |

## Integration

`default.nix` is a pure import aggregator. It is imported by `modules/common/programs.nix` so Thunderbird lands on every platform (NixOS killua, handheld, archnix, macnix) via the shared `cross-platform` module. Gated by `lib.mkDefault (pkgs.stdenv.isLinux || pkgs.stdenv.isDarwin)` so adding non-Unix platforms later is safe.

## Add-on Packaging

No NUR set for Thunderbird exists -- `nur.repos.rycee.thunderbird-addons` is not a real attribute path. Each add-on is packaged inline using `pkgs.nur.repos.rycee.firefox-addons.buildFirefoxXpiAddon`, which produces the exact `share/mozilla/extensions/{ec80...}/<addonId>.xpi` layout that Home Manager's `programs.thunderbird.profiles.<name>.extensions` consumes (HM reuses Firefox's extension GUID path for TB -- see `home-manager/modules/programs/thunderbird.nix` line ~1008).

## Gotcha: `extensions.autoDisableScopes = 0`

Home Manager symlinks the XPIs into the profile but Thunderbird marks externally-added add-ons as **disabled** on first run by default. The `"extensions.autoDisableScopes" = 0;` pref in `profiles.default.settings` suppresses this; without it you must manually enable each add-on in Tools > Add-ons Manager after first launch.

## Add-on Set (ATN slugs)

| Slug | GUID | Purpose |
|---|---|---|
| `gmail-conversation-view` | `gconversation@xulforum.org` | Gmail-style threaded conversation view |
| `filtaquilla` | `filtaquilla@mesquilla.com` | Extended filter conditions and actions |
| `quicktext` | `{8845E3B3-E8FB-40E2-95E9-EC40294818C4}` | Keyword-triggered snippet / template insertion |
| `mailmindr` | `mailmindr@arndissler.net` | Per-message follow-up reminders |
| `send-later-3` | `sendlater3@kamens.us` | Scheduled and recurring send |
| `minimizetotray-reanimated` | `mintray-reanimated@ysard` | Minimize-to-tray and start-hidden |
| `removedupes` | `{a300a000-5e21-4ee0-a115-9ec8f4eaa92b}` | Find and delete duplicate messages |
| `header-tools-lite` | `headerToolsLite@kaosmos.nnp` | Edit headers, resend, view raw source |

## Bumping Add-ons

1. Look up the new XPI URL in the ATN API: `https://addons.thunderbird.net/api/v4/addons/addon/<slug>/` -> `current_version.files[0].url`
2. Compute SHA: `nix-prefetch-url <url>`
3. Update `url`, `version`, `sha256` in the corresponding `buildXpi` block.

## Skipped Add-ons (superseded by built-ins in TB 115+/128 ESR)

- Lightning (calendar + CalDAV) -- native
- Enigmail (OpenPGP) -- native
- CardBook (CardDAV) -- native
- Chat / Matrix -- native
- Feed reader -- native

## No Accounts Wired

No mail accounts are declared. Log in via the first-run account wizard. To move to declarative accounts later, use `programs.thunderbird.profiles.<name>.userContent` or `home-manager`'s `accounts.email` integration with `thunderbird.enable = true` per account, sourcing credentials from `sops-nix` (see `modules/common/sops.nix`).
