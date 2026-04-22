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

Qutebrowser is remapped to Colemak-DH via explicit `keyBindings` (not `keyMappings`, which is left empty because its chained resolution creates cycles):

- `n/e/i/o` map to scroll left/down/up/right (replacing vim `h/j/k/l`)
- Displaced keys reassigned: `h` = search-next, `k` = undo, `u` = enter insert mode, `y` = open prompt, and `l` is unbound so the keychains `ll/lt/ld/lp` yank URL/title/domain/pretty-url
- Half-page scroll bound to `{` / `}`, tab navigation to `N` / `O`, back/forward on `E` / `I`
- Hint characters use Colemak home row: `arstneio`
