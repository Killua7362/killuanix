# Chat Module

Home Manager module for messaging-aggregator apps. Currently just Ferdium.

## Files

| File | Description |
|---|---|
| `default.nix` | Entry point; imports `./ferdium.nix` |
| `ferdium.nix` | Installs `pkgs.ferdium` and renders `~/.config/Ferdium/config/custom.css` from `config.theme.palette` |

## Integration

Imported per-host (NixOS only) from `chrollo/home-manager/home.nix` and `killua/home.nix`. **Not** wired into `modules/common/programs.nix` — that would also push it onto archnix and macnix, which the user does not want. Module body is gated by `lib.mkIf pkgs.stdenv.isLinux` as a defensive guard.

## What is declarative — and what is not

Ferdium has no `programs.ferdium` home-manager module and rewrites `~/.config/Ferdium/config/{config,services}.json` on every launch. The only file that is **safe** to manage declaratively under `~/.config/Ferdium/config/` is `custom.css`. Everything else (window placement, dark-mode toggle inside the app, enabled services, message badges, notifications, OS integrations) is GUI-managed and lives in the JSON files Ferdium owns.

| Concern | Declarative? | Where |
|---|---|---|
| Package installed | yes | `home.packages` |
| App theming | yes | `xdg.configFile."Ferdium/config/custom.css".text` |
| Service list (Discord/Slack/...) | **no** | added via GUI: *Settings → Services → Add a new service* |
| Per-service credentials | **no** | login via each service's web UI inside Ferdium |
| Notifications, hotkeys, startup tweaks | **no** | *Settings → General* |
| Workspaces | **no** | *Workspaces drawer* |

## custom.css

`ferdium.nix` builds a heavy-override dark scheme from `config.theme.palette` (`bg`, `surface`, `surface_low`, `surface_high`, `outline`, `fg`, `fg_bright`, `fg_dim`, `fg_muted`, `color4` as accent, `error`, `selection_bg`, `selection_fg`). Selectors target the Ferdium shell (`.sidebar`, `.tab-item`, `.app`, `.titlebar`, `.settings*`, `.franz-form__*`, `.recipe-teaser`, `.workspaces-drawer__item`).

Per-service webviews (Slack, Discord, etc.) sit in isolated `<webview>` frames and **ignore** `custom.css` — each service has its own theme. The override only restyles Ferdium itself.

If a Ferdium release renames the CSS classes and the heavy override breaks, the cheapest fix is to revert to an accent-only override: keep the `--killua-accent` block and the `.sidebar .tab-item.is-active` rule, delete the rest.

## Sops

The sops key `ferdium_services` (declared in `modules/common/sops.nix`) is a multi-line YAML scalar holding the user's intended recipe list — services to add after first launch, with login URLs and notes. **It is not auto-applied** — Ferdium offers no headless login or service-import API. The note is a setup runbook only; decrypt with:

```
sops -d --extract '["ferdium_services"]' secrets/personal.yaml
```

## Post-install runbook

1. `scripts/nix_switch <host>` to apply.
2. Launch Ferdium. Confirm `~/.config/Ferdium/config/custom.css` is a read-only symlink into `/nix/store/...`.
3. Sign up / log in to the local Ferdium account on first launch (Ferdium offers an offline "Use Ferdium without an account" option — pick that if you don't want their sync).
4. Decrypt the `ferdium_services` note (see above) and add each service via the in-app Services panel.
5. For each added service, log in inside its embedded webview.
6. None of step 4 or 5 survives a fresh data wipe — `~/.config/Ferdium/` data must be backed up out-of-band if you care.

## Gotchas

- Ferdium uses Electron — picks Wayland automatically because `NIXOS_OZONE_WL` is exported globally on chrollo + killua. If rendering ever breaks, force XWayland with `--ozone-platform=x11`.
- `xdg.configFile` writes a symlink, not a regular file. Ferdium handles this fine because it only reads `custom.css`; it doesn't try to rewrite it.
- The `custom.css` reload requires a Ferdium restart (no live-reload).
