# Browsers Module

Shared Home Manager module that configures web browsers across all platforms.

## Files

| File | Description |
|---|---|
| `default.nix` | Entry point; imports `./firefox` and `./qutebrowser.nix` |
| `qutebrowser.nix` | Qutebrowser configuration (Linux only via `mkDefault`). Includes Colemak-DH key remapping, privacy-hardened content settings, dual ad-blocking (adblock + hosts lists), dark mode, custom search engines mirroring Firefox, and a Python interceptor that redirects reddit.com to old.reddit.com. |
| `firefox/default.nix` | Firefox Nightly with Arkenfox hardening, Natsumi Browser CSS theme, enterprise-policy extensions, and extensive user preferences. |

## Submodules

- [`firefox/CLAUDE.md`](firefox/CLAUDE.md) -- detailed documentation of the Firefox configuration

## Integration

`default.nix` is a pure import aggregator with no options or logic. It is imported by `modules/common/programs.nix` as part of the shared program set consumed by all platforms through `modules/cross-platform/default.nix`.

## Qutebrowser Key Layout

Qutebrowser uses `keyMappings` to globally remap vim-style defaults to Colemak-DH:

- `n/e/i/o` map to `h/j/k/l` (left/down/up/right)
- Displaced keys (`h`, `k`, `j`, `l`, `u`) are reassigned to preserve next-match, undo, end-of-word, yank, and insert functionality
- Half-page scroll bound to `{` / `}`, tab navigation to `N` / `O`
- Hint characters use Colemak home row: `arstneio`
