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
- **`extensions.packages`** (NUR) -- installed into the default profile. Privacy/QoL: uBlock Origin, SponsorBlock, ClearURLs, Old Reddit Redirect, YouTube Redux, Return YouTube Dislikes, Reddit Enhancement Suite, Dark Reader, FastForward, Violentmonkey, Web Clipper Obsidian. Power-user additions: Multi-Account Containers, Temporary Containers, CanvasBlocker, Consent-O-Matic, LibRedirect, Header Editor, User-Agent String Switcher, Hoppscotch, Refined GitHub, SingleFile, Stylus, DeArrow

## Userscript Bookmark Folder

A "Userscripts" folder is seeded into the bookmarks via `profiles.default.bookmarks` (declarative, `force = true`). Each entry links directly to a `*.user.js` URL on greasyfork.org -- Violentmonkey auto-prompts to install on click. This is the realistic declarative path because Violentmonkey stores installed scripts in browser IndexedDB, which cannot be materialized from the Nix store.

Curated set covers: paywall bypass, link-shortener bypass, Reddit tweaks, GitHub UX, Google/DDG AI-answer removal, Twitter/X cleanup, image-search direct download, anti-adblock-killer. If any URL 404s after a Greasyfork slug update, strip to `/scripts/<id>` and Greasyfork will redirect; update the pin afterwards.

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
