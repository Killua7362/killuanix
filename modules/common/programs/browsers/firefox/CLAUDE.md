# Firefox Module

Home Manager configuration for Firefox, using Firefox Nightly with the Arkenfox user.js hardening profile and the Natsumi Browser custom CSS theme.

## Custom Chrome

The module builds a merged `chrome/` directory from two sources:

- **natsumi-browser** -- custom CSS theme providing a translucent, colorful UI
- **fx-autoconfig** (MrOtherGuy) -- enables userChrome.js script loading via a patched `config.js` injected through `extraPrefsFiles`

A custom `chrome.manifest` wires natsumi's scripts, CSS, and icons into the fx-autoconfig loader.

## Extensions

Extensions are installed through two mechanisms. Enable/disable state is **only** seeded on first profile init via the `firefoxSeedDisabledExtensions` activation script (see below) — after that Firefox owns `extensions.json` and user toggles in `about:addons` persist normally. `extensions.autoDisableScopes = 0` in `extraConfig` so newly-installed addons come up enabled by default.

- **`policies.ExtensionSettings`** -- installed via Mozilla enterprise policy (`installation_mode = "normal_installed"`, user can disable/uninstall). Two helpers:
  - `extension shortId uuid` — builds the AMO `/latest/<shortId>/latest.xpi` URL.
  - `extensionUrl url uuid` — pins to a specific XPI URL when `/latest/` is unreliable (themes, single-version uploads).
  - Currently: Tree Style Tab, uBlock Origin, Bitwarden, Tabliss, uMatrix, LibreRedirect, ClearURLs, Pywalfox, Audio Selector, ColorPick Eyedropper, Song ID, Video Speed Controller, Full Screen, Font Finder, YouTube Playlist Duration Calculator, insta-viewer (version-pinned).
- **`extensions.packages`** (NUR) -- installed into the default profile from `pkgs.nur.repos.rycee.firefox-addons`:
  - Privacy/QoL: uBlock Origin, SponsorBlock, ClearURLs, Old Reddit Redirect, YouTube Redux, Return YouTube Dislikes, Reddit Enhancement Suite, Dark Reader, FastForward, Violentmonkey, Web Clipper Obsidian, DeArrow.
  - Power-user: Multi-Account Containers, Temporary Containers, CanvasBlocker, Consent-O-Matic, LibRedirect, Header Editor, User-Agent String Switcher, Hoppscotch, Refined GitHub, SingleFile, Stylus.
  - Added from live-profile inventory: Firefox Color, FoxyProxy, Greasemonkey, Keepa, nightTab, OneTab, React Developer Tools, Userchrome Toggle, Download with JDownloader.
  - The Karakeep browser extension (paired with the karakeep container at http://localhost:9090) is **not** in NUR yet, so it's installed manually from AMO and configured with an API token from Settings → API Keys. Same for several themes (Browser Zen Dark, Dark Space, GF-S Tamayori, Kazuha, Zen Theme, Zhongli, Black) — left manual because AMO `/latest/` redirects are flaky for themes; pin a specific XPI via `extensionUrl` if you want one of them declarative.

## One-shot `userDisabled` seed

`home.activation.firefoxSeedDisabledExtensions` patches `~/.mozilla/firefox/default/extensions.json` once to set `userDisabled = true` + `active = false` for IDs listed in the top-of-file `initiallyDisabledExtensionIds` attribute. Behavior:

- Gated by sentinel `~/.mozilla/firefox/default/.hm-extensions-disabled-seeded`. Present → no-op.
- Skips (without writing the sentinel) if `extensions.json` is missing (profile not yet initialized — re-runs on next switch after first Firefox launch).
- Skips if Firefox is running (`pgrep -x firefox` / `firefox-bin`) — Firefox would clobber the patch on exit. Re-runs on next switch.
- Uses `jq` to merge in-place via tmpfile + `mv` (atomic), so it never partially-wrecks the file.

To re-seed (e.g. you reset the profile or want a new addon added to the disabled set): delete the sentinel, ensure Firefox is closed, run `home-manager switch`. To extend the list, edit `initiallyDisabledExtensionIds` in `default.nix` *and* delete the sentinel.

This is the only place HM touches `extensions.json` — `extensions.force` stays off so manually-installed addons (e.g. Karakeep) are preserved across switches per [`feedback_firefox_bookmarks`].

## Bitwarden Desktop Integration

`pkgs.bitwarden-desktop` is added to `home.packages`, and a Mozilla native-messaging manifest is generated via `pkgs.writeTextFile` (the upstream nix package ships `libexec/desktop_proxy` but no manifest). The manifest is wired in via `programs.firefox.nativeMessagingHosts`, landing at `~/.mozilla/native-messaging-hosts/com.8bit.bitwarden.json` and pointing at the desktop_proxy binary. Allowed extension is locked to Bitwarden's UUID `{446900e4-71c2-419f-a6a7-df9c091e268b}`.

After first run: open the desktop app, log in, then **Settings → Allow browser integration** (and **Allow browser communication over WebSockets** if needed). In the Firefox extension: **Settings → Biometrics → Use browser integration**. Enables biometric/PIN unlock from the extension via the desktop app.

**Vault timeout / lock action cannot be set declaratively.** It is per-account state in the extension's IndexedDB and the desktop app's encrypted `data.json`. The Bitwarden browser-extension managed-storage schema only exposes `environment`, `enableBrowserIntegration`, `enableBrowserIntegrationFingerprint`, and `disablePersonalVaultExport` -- timeout is not in there. Only Bitwarden Enterprise org policies (server-side, paid plan) can enforce timeout. Set it once via the extension UI: **Account security → Vault timeout (15 min) + Vault timeout action (Lock)**. Aggressive auto-lock is the main mitigation for the WebExtensions process growing to 1+ GB on long sessions.

## Bookmarks

**User bookmarks are NOT managed declaratively.** The HM `profiles.<name>.bookmarks` option with `force = true` overwrites `places.sqlite` on every switch and wipes user-added bookmarks -- never use it.

Shared/declarative entries go through `policies.ManagedBookmarks` instead. This is a Firefox enterprise policy that produces a read-only **Managed Bookmarks** toolbar folder backed by a separate store from `places.sqlite`, so it does not touch user-managed bookmarks. Currently seeded with two subfolders:

- **Self-hosted** -- toolbar shortcuts to local container UIs (Dashboard, Portainer, SearXNG, LiteLLM, Qdrant, MCP Hub, Excalidraw, Mermaid Live)
- **Userscripts** -- direct links to `*.user.js` URLs on greasyfork.org; Violentmonkey auto-prompts to install on click. Violentmonkey stores installed scripts in IndexedDB which cannot be materialized from the Nix store, so this curated link list is the realistic declarative path. If a URL 404s after a Greasyfork slug update, strip to `/scripts/<id>` and Greasyfork will redirect; update the pin afterwards.

## Vendored userscripts

`scripts/` holds Violentmonkey-style `*.user.js` files vendored into the repo (Greasy Fork scripts, gists, etc.). Violentmonkey can't load them from the Nix store directly -- install by opening the file in Firefox (`file://...`) or pasting its contents into Violentmonkey's editor. Currently:

- `medium-paywall-bypass.user.js` -- redirects medium.com articles via freedium-mirror.cfd (originally a [gist by mathix420](https://gist.github.com/mathix420/e0604ab0e916622972372711d2829555)).

## Stylus styles

Stylus stores user styles in its WebExtension IndexedDB, which can't be materialized from the Nix store (same constraint already documented for Violentmonkey scripts and Karakeep). The realistic declarative path is a curated Stylus **backup JSON** that ships in the repo and is imported once via the Stylus UI.

- `stylus-styles.json` -- Stylus backup format (array of style objects with `name`, `sections`, `enabled`, etc.). Currently seeds one style: `Global Dark — Invert`, a `filter: invert(1) hue-rotate(180deg)` page-wide dark mode with an inner re-invert on media (`img, picture, video, iframe, canvas, svg, embed, object, [style*="background-image"]`) so photos and logos render normally. Applies to all `http://` and `https://` URLs.
- The JSON is symlinked into the profile at `~/.mozilla/firefox/default/stylus-styles.json` via a `home.file` entry next to the chrome wiring, so the import file picker can reach it without typing a Nix-store path.

**Import** (one-time, after a switch on a fresh profile): Stylus toolbar icon → **Manage** → top-right gear → **Backup → Import** → pick `~/.mozilla/firefox/default/stylus-styles.json`. Stylus reports `imported 1 style`.

**Overlap with Dark Reader.** Dark Reader (also in `extensions.packages`) covers the same "global dark for all sites" use case and does a better job on photo-heavy and custom-themed pages. The Stylus style is provided as an alternative -- if both are active the page is over-darkened, so disable one. Disable Dark Reader per-site from its popup, or disable the Stylus style from Stylus's popup toggle; deleting the Stylus style only removes the IndexedDB copy, the JSON in the Nix store stays.

**Editing the bundled set.** Add or tweak styles via the Stylus UI, then export the full backup (Manage → Backup → Export) and overwrite `stylus-styles.json` in the repo. The Nix store path changes on the next switch and the symlink follows.

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
