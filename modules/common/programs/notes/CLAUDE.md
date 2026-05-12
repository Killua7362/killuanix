# Notes Module

Home Manager module for [Obsidian](https://obsidian.md/), configuring a single vault named `killuanix-notes` at `$HOME/killuanix/Notes`. This module is NixOS-only — it is imported by `chrollo/home-manager/home.nix` and `killua/home.nix`, NOT by `modules/common/programs.nix`. Archnix and macnix do not receive Obsidian via this module.

## Files

| File | Description |
|---|---|
| `default.nix` | Pure import aggregator; imports `./obsidian.nix`. |
| `obsidian.nix` | Full `programs.obsidian` config — vault, AnuPpuccin theme (Atom Dark via the extended-colorschemes snippet + Style Settings), palette CSS snippet, core and community plugins, hotkeys, Colemak vim keymap, and `home.file` entries for templates and `_claude/` symlinks. |
| `templates/` | Markdown scaffolds copied into `<vault>/templates/` by `home.file`: `daily.md`, `meeting.md`, `project.md`, `clipper.md`. |

## Theme & Palette CSS

The [AnuPpuccin](https://github.com/AnubisNekhet/AnuPpuccin) theme by @AnubisNekhet is pinned via `builtins.fetchGit` at a specific rev and wrapped as a derivation (`pkgs.runCommand "obsidian-theme-anuppuccin"`) that copies `manifest.json` and `theme.css` (falling back to `obsidian.css`) into the layout Obsidian's HM module installs under `.obsidian/themes/AnuPpuccin/`.

AnuPpuccin's base theme only ships the Catppuccin flavors (Frappe / Macchiato / Mocha / Mocha-Old). The **Atom Dark** palette lives in the optional `snippets/extended-colorschemes.css` from the same repo — that file is read out of the fetched source and registered as the `anuppuccin-extended-colorschemes` snippet. The selection itself is driven by the **Style Settings** plugin (`op.obsidian-style-settings`), whose `data.json` is seeded with these keys:

| Key | Value | Effect |
|---|---|---|
| `anuppuccin-theme-settings-extended@@anp-theme-ext-dark` | `true` | Toggles the `anp-theme-ext-dark` class on body so the extended dark scheme actually engages |
| `anuppuccin-theme-settings-extended@@catppuccin-theme-dark-extended` | `"ctp-atom-dark"` | Picks Atom Dark from the extended dropdown |
| `anuppuccin-theme-settings@@anp-alt-rainbow-style` | `"anp-simple-rainbow-color-toggle"` | Enables simple rainbow folders |
| `anuppuccin-theme-settings@@anp-simple-rainbow-title-toggle` | `true` | Colors folder title text |
| `anuppuccin-theme-settings@@anp-simple-rainbow-collapse-icon-toggle` | `true` | Colors folder collapse icons |
| `anuppuccin-theme-settings@@anp-simple-rainbow-indentation-toggle` | `true` | Colors indent guides |
| `anuppuccin-theme-settings@@anp-simple-rainbow-icon-toggle` | `true` | Appends a colored ⬤ dot after each folder name |
| `anuppuccin-theme-settings@@anp-rainbow-subfolder-color-toggle` | `true` | Subfolders inherit parent's color |
| `anp-custom-rainbow-colors@@rainbow-color-repeat` | `"rainbow-repeat-11"` | Cycles all 11 Catppuccin accent colors |
| `anuppuccin-theme-settings@@anp-alt-tab-style` | `"anp-mini-tab-toggle"` | Minimalistic tabs: flat with a bottom underline on the active tab |

The `<@settings.id>@@<item.id>` format is the Style Settings plugin's data-file convention. The rainbow folder styles are provided by the `anuppuccin-custom-rainbow-colors` snippet (from `snippets/custom-rainbow-colors.css` in the same source), enabled alongside the extended colorschemes snippet.

On top of the theme, a single CSS snippet named `palette` (registered via `cssSnippets`) does three things:

- Forces the editor monospace font to `JetBrainsMono Nerd Font` (falls back to `JetBrains Mono`, `ui-monospace`, `monospace`) with `font-feature-settings: "liga", "calt"` so kitty-style ligatures render in source view, preview, and inline code.
- Zeros `--file-margins` / `--file-folding-offset` and sets `padding-left/right: 0` + `max-width: 100%` on source, preview, and reading containers so notes fill the entire pane. `readableLineLength = false` in `app.json` takes care of the narrow-column setting; this snippet removes the residual frame padding the theme adds.
- Zeros `.cm-scroller` top padding so the first heading sits flush with the pane top.

The previous Minimal-era kitty-bg override (`--background-primary` / `--background-secondary` driven by `config.theme.palette`) is intentionally gone — Atom Dark has its own palette and overriding it would defeat the point of the theme switch.

## Core Plugins

Enabled via `corePlugins`: `templates` (folder `templates`, format `YYYY-MM-DD`), `daily-notes` (folder `dailies`, format `YYYY-MM-DD`, template `templates/daily.md`), `file-explorer`, `global-search`, `switcher`, `graph`, `backlink`, `outgoing-link`, `outline`, `tag-pane`, `properties`, `page-preview`, `command-palette`, `file-recovery`, `bookmarks`, `canvas`, `editor-status`, `word-count`, `note-composer`.

## Community Plugins

All community plugins come from `pkgs.obsidianPlugins` (aliased as `op` in the module):

| Plugin | Purpose |
|---|---|
| `obsidian-style-settings` | Drives AnuPpuccin's palette selection. Seeded with `anp-theme-ext-dark = true` and `catppuccin-theme-dark-extended = "ctp-atom-dark"` (Style Settings keys use `<@settings.id>@@<item.id>` form, see the theme section). Open *Settings → Style Settings → AnuPpuccin Themes Extended* to tweak further palettes. |
| `obsidian-git` | Git backup. **All automatic behaviors off** — `autoSaveInterval`, `autoPushInterval`, `autoPullInterval` are `0` and `autoPullOnBoot = false`. Commits/pushes/pulls happen only via the command palette (Obsidian Git: Create backup / Push / Pull). Commit message is `vault: {{date}}` with format `YYYY-MM-DD HH:mm:ss`. |
| `dataview` | Query-based views over note frontmatter. |
| `obsidian-excalidraw-plugin` | Excalidraw drawings as `.excalidraw.md` files. |
| `obsidian-diagrams-net` | Draw.io embedded editor for `.drawio.svg` / `.drawio.png` diagrams (zapthedingbat's plugin). |
| `mermaid-tools`, `mermaid-themes`, `mermaid-popup`, `mermaid-helper` | Mermaid theming, quick actions, hover preview, helper insertions. |
| `diagram-zoom-drag` | Zoom/pan on diagram blocks. |
| `table-editor-obsidian` | Table editing UX. |
| `obsidian-tasks-plugin` | Task queries and completion tracking. |
| `calendar` | Calendar sidebar tied to daily notes. |
| `templater-obsidian` | Templater (advanced `<% … %>` templates). |
| `nldates-obsidian` | Natural-language date parsing. |
| `obsidian-vimrc-support` | Reads `<vault>/.obsidian.vimrc` at startup so Obsidian's vim mode can be customized like `.vimrc` / `init.vim`. |
| `obsidian-image-toolkit` | Zoom with Ctrl+scroll and drag-to-pan (left-click) for images. |
| `obsidian-icon-folder` | Per-file/folder icons in the explorer (Iconize). **Settings are NOT in `communityPlugins`** — they're written via `home.file` directly as `data.json` because the HM obsidian module puts plugin settings at the top level of data.json while Iconize reads from `data.settings` (nested key). Top-level settings cause `TypeError: Cannot read properties of undefined` and crash the plugin. `migrated: 6` is seeded to skip all five migration steps (each calls saveData through the read-only Nix-store symlink). Icon rules: `^dailies$`→LiCalendarDays, `^templates$`→LiLayoutTemplate, `^_inbox$`→LiInbox, `^_claude$`→LiBot, `^skills$`→LiBrainCircuit, specific template files (clipper/daily/meeting/project), canvas/excalidraw, `*.md` fallback. Icons use `Li` prefix (Iconize's native Lucide pack prefix), not `Lu` (which is the Lucide React convention). |

## Obsidian Settings

Under `vaults."killuanix-notes".settings.app`:

- `readableLineLength = false` — full-width notes (paired with the palette CSS).
- `livePreview = true`, `defaultViewMode = "source"` — start in live-preview source mode.
- `vimMode = true` — enable vim keybindings (consumed by `obsidian-vimrc-support`).
- `promptDelete = false`, `showLineNumber = true`.
- `alwaysUpdateLinks = true`, `useMarkdownLinks = false`, `newLinkFormat = "shortest"` — prefer wiki-style shortest links and keep them up to date on rename.
- `appearance.baseFontSize = 16`.

## Hotkeys

| Action | Binding |
|---|---|
| `editor:toggle-bold` | Mod+B |
| `editor:toggle-italics` | Mod+I |
| `command-palette:open` | Mod+P |
| `switcher:open` | Mod+O |
| `workspace:split-vertical` | Mod+\ |
| `app:go-back` | Mod+Alt+ArrowLeft |
| `app:go-forward` | Mod+Alt+ArrowRight |
| `daily-notes` | Mod+Shift+D |

## Vim Keymap (Colemak)

Written to `<vault>/.obsidian.vimrc` as a plain string (read by `obsidian-vimrc-support`). Uses `noremap` explicitly throughout — the plugin aliases `map` to `noremap` but the explicit form is unambiguous.

| Key | Maps to | Notes |
|---|---|---|
| `n` / `e` / `i` / `o` | `h` / `j` / `k` / `l` | Colemak NEIO motion in normal and visual mode |
| `u` / `U` | `i` / `I` | Insert / append |
| `y` / `Y` | `o` / `O` | Open new line below / above |
| `j` | `e` | End-of-word (since `j` moved to `e`) |
| `h` / `H` | `n` / `N` | Search next / previous |
| `l` | `y` | Yank (normal + visual) |
| `k` | `u` | Undo |
| `;;` | `:cmdPalette<CR>` | Diagnostic canary — if `;;` doesn't open the command palette, the vimrc isn't loading at all |

The `;;` binding defines a custom `exmap cmdPalette obcommand command-palette:open` first, then binds it in normal mode. Use it as a quick sanity check that `obsidian-vimrc-support` picked up the file.

## Symlinks into `_claude/`

`home.file` surfaces live Claude Code state into the vault so Obsidian can open and edit it directly. The live symlinks use `config.lib.file.mkOutOfStoreSymlink`, which points at the real path instead of the Nix store — edits write through in both directions.

| Vault path | Points to | Mode |
|---|---|---|
| `_claude/plans` | `~/.claude/plans` | Live symlink (edits propagate bidirectionally) |
| `_claude/skills` | `~/killuanix/Notes/claude/skills` | Live symlink (edits propagate bidirectionally) — same dir surfaced under `<vault>/claude/skills` canonically, the `_claude/skills` entry is just an aggregator view |
| `_claude/docs/root-CLAUDE.md` | `~/killuanix/CLAUDE.md` | Live symlink |
| `_claude/docs/dev-CLAUDE.md` | `~/killuanix/modules/common/programs/dev/CLAUDE.md` | Live symlink |
| `_claude/docs/browsers-CLAUDE.md` | `~/killuanix/modules/common/programs/browsers/CLAUDE.md` | Live symlink |
| `_claude/docs/hyprland-CLAUDE.md` | `~/killuanix/modules/common/programs/desktop/hyprland/CLAUDE.md` | Live symlink |
| `_claude/docs/utils-CLAUDE.md` | `~/killuanix/modules/common/programs/utils/CLAUDE.md` | Live symlink |

`_claude/` is gitignored — it's a transient view. The committed canonical Claude state lives at `<vault>/claude/` (no underscore), wired in the **opposite direction** by `modules/common/programs/dev/claude.nix`:

| Live `~/.claude/` path | Symlinks to vault file | Owner |
|---|---|---|
| `~/.claude/CLAUDE.md` | `<vault>/claude/global.md` | Notes submodule (committed) |
| `~/.claude/projects/-home-killua-killuanix/memory/` | `<vault>/claude/memory/` | Notes submodule (committed); auto-memory writes land here |

Don't conflate the two: `_claude/` is a viewing aggregator (what Claude Code state looks like), `claude/` is the canonical store (what the user pushes to git).

## Templates

Markdown templates in `./templates/` are copied into `<vault>/templates/` via `home.file.<vaultRel>/templates/<name>.md.source = ./templates/<name>.md`:

| Template | Frontmatter / Placeholders |
|---|---|
| `daily.md` | `date`, `tags: [daily]`; `# {{date:dddd, MMMM Do YYYY}}` with Focus / Notes / Log sections. Used by the `daily-notes` core plugin. |
| `meeting.md` | `date`, `tags: [meeting]`, `attendees: []`; `# Meeting — {{title}}` with Agenda / Notes / Action Items. |
| `project.md` | `created`, `status: active`, `tags: [project]`; `# {{title}}` with Goal / Milestones / Resources / Log. |
| `clipper.md` | `source`, `author`, `published`, `clipped`, `tags: [inbox, clipped]`; `# {{title}}` + `{{content}}`. Consumed by the Obsidian Web Clipper Firefox extension (see `modules/common/programs/dev/skills/obsidian-clipper/SKILL.md`). |

Templates are rendered by the `templates` core plugin (simple `{{date}}` / `{{title}}` placeholders) and/or Templater (`<% … %>` blocks) depending on which syntax the file uses.

## Integration

This module is imported **only** by NixOS entry points:

- `chrollo/home-manager/home.nix` — imports `../../modules/common/programs/notes`
- `killua/home.nix` — imports `../modules/common/programs/notes`

It is deliberately **not** imported by `modules/common/programs.nix`, so the cross-platform HM aggregator does not pull it into archnix or macnix. Obsidian is declared once per NixOS host rather than as a shared-everywhere program.

## Gotchas

- **Templates live in the flake, not the vault.** `<vault>/templates/*.md` files are Home-Manager-managed symlinks into the Nix store. Editing the vault copies has no effect — the next `home-manager switch` will re-pin them from the flake. To change a template, edit `modules/common/programs/notes/templates/<name>.md` in the flake and rebuild.
- **`.obsidian.vimrc` is HM-managed.** The file at `<vault>/.obsidian.vimrc` is written from the `obsidianVimrc` string in `obsidian.nix`. `Notes/.gitignore` already excludes it from the submodule, so edits to the live file are lost on rebuild — change the string in `obsidian.nix` instead.
- **Obsidian Git has all automatic behaviors disabled.** `autoSaveInterval = 0`, `autoPushInterval = 0`, `autoPullInterval = 0`, `autoPullOnBoot = false`. Commits, pushes, and pulls happen only when triggered from the command palette (`Obsidian Git: Create backup` / `Push` / `Pull`). This is intentional — the vault is a submodule and auto-committing from Obsidian would race with `git` activity in the parent repo.
- **`_claude/plans` and `_claude/skills` are live symlinks.** Both use `mkOutOfStoreSymlink`, so edits made inside Obsidian write through to `~/.claude/plans` and `~/killuanix/Notes/claude/skills` respectively. The skills target is **inside the same vault** (`Notes/claude/skills/`) — `_claude/skills` is purely an aggregator view; the canonical path is `<vault>/claude/skills/`. Renaming/deleting under either path edits the live skill source Claude Code reads at `~/.claude/skills/<name>` (also a live symlink, wired by `modules/common/programs/dev/ai/claude.nix`).
- **Diagnostic canary.** If vim mappings don't apply at all (not just a single binding misbehaving), press `;;` in normal mode. If the command palette doesn't open, `obsidian-vimrc-support` isn't loading the file — the issue is the plugin or the file path, not the keymap syntax.
