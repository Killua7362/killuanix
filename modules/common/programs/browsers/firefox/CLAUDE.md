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
- **`extensions.packages`** (NUR) -- installed into the default profile. Privacy/QoL: uBlock Origin, SponsorBlock, ClearURLs, Old Reddit Redirect, YouTube Redux, Return YouTube Dislikes, Reddit Enhancement Suite, Dark Reader, FastForward, Violentmonkey, Web Clipper Obsidian. Power-user additions: Multi-Account Containers, Temporary Containers, CanvasBlocker, Consent-O-Matic, LibRedirect, Header Editor, User-Agent String Switcher, Hoppscotch, Refined GitHub, SingleFile, Stylus, DeArrow. The Karakeep browser extension (paired with the karakeep container at http://localhost:9090) is **not** in NUR yet, so it's installed manually from AMO and configured with an API token from Settings → API Keys.

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
