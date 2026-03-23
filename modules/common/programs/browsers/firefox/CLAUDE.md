# Firefox Module

Home Manager configuration for Firefox, using Firefox Nightly with the Arkenfox user.js hardening profile and the Natsumi Browser custom CSS theme.

## Custom Chrome

The module builds a merged `chrome/` directory from two sources:

- **natsumi-browser** -- custom CSS theme providing a translucent, colorful UI
- **fx-autoconfig** (MrOtherGuy) -- enables userChrome.js script loading via a patched `config.js` injected through `extraPrefsFiles`

A custom `chrome.manifest` wires natsumi's scripts, CSS, and icons into the fx-autoconfig loader.

## Extensions

Extensions are installed through two mechanisms:

- **`policies.ExtensionSettings`** -- force-installed via Mozilla enterprise policy: Tree Style Tab, uBlock Origin, Bitwarden, Tabliss, uMatrix, LibreRedirect, ClearURLs
- **`extensions.packages`** (NUR) -- installed into the default profile: uBlock Origin, SponsorBlock, ClearURLs, Old Reddit Redirect, YouTube Redux, Return YouTube Dislikes, Reddit Enhancement Suite, Dark Reader, FastForward, Violentmonkey

## uBlock Origin Policy

uBlock Origin is configured via managed storage with a dark UI theme, cloud storage disabled, and custom filter lists including OISD, YouTube Shorts hiding, and a custom `ytbetter` list. Standard lists (EasyList, EasyPrivacy, AdGuard, uBlock built-ins, URLhaus) are also enabled.

## Search Engines

Default search is Google. Custom engines defined: Nix Packages (`@np`), NixOS Wiki (`@nw`), Searx (`@searx`). Bing is hidden.

## Arkenfox Profile

The default profile enables Arkenfox with selective section overrides:

- **0100** -- startup page and new tab page re-enabled
- **0300** -- quiet Fox (disable update checks, telemetry)
- **2400** -- DOM/API restrictions
- **2600** -- partial (2603 only)
- **2800** -- sanitize on shutdown, but 2815 (cache clearing) disabled
- **4000** -- fingerprinting protection with CSS color scheme override
- **4500** -- mostly disabled; letterboxing off, WebGL allowed, system colors enabled

## Extra Preferences

Extensive `extraConfig` block covering:

- Natsumi theme prefs (`natsumi.theme.type = "colorful"`, translucency disabled, non-floating URL bar)
- Native vertical tabs via `sidebar.verticalTabs`
- Picture-in-picture always enabled
- Fullscreen warning suppressed
- Dark mode forced across UI and content
- Custom scrollbar styling, selection/highlight colors, spell-check underline
- Tab behavior: insert after current, don't close window with last tab, ctrl+tab sorts by recency
- fx-autoconfig/userChromeJS support prefs
- Signature requirement disabled for unsigned extensions
