---
name: obsidian-vault
description: Create, read, edit, and organize notes in the user's Obsidian vault at ~/killuanix/Notes. Use when the user asks about their vault, notes, daily notes, wants to capture an idea, search notes, link related content, insert a template, or when editing files under ~/killuanix/Notes. Also applies when editing CLAUDE.md files or skills surfaced through the vault's _claude/ tree.
---

# Obsidian Vault — Note authoring and curation

The user keeps one Obsidian vault at `~/killuanix/Notes` (a git submodule of the killuanix flake). Home Manager owns `~/killuanix/Notes/.obsidian/` exclusively — never edit files inside `.obsidian/`, they are rewritten on every rebuild.

## Vault layout

| Path | Contents |
|---|---|
| `dailies/YYYY-MM-DD.md` | Daily notes, auto-created by the `daily-notes` core plugin. Template: `templates/daily.md`. |
| `templates/` | HM-managed markdown templates: `daily.md`, `meeting.md`, `project.md`, `clipper.md`. Files here are pinned from the flake — edit them in the flake (`modules/common/programs/notes/templates/`), not in the vault. |
| `_inbox/` | Web Clipper output lands here — one markdown file per clip. Needs triage (tag, move, backlink). |
| `_claude/plans/` | Symlink to `~/.claude/plans/`. Editing here writes through to the real plan file. |
| `_claude/skills/` | Symlink to `modules/common/programs/dev/skills/` in the flake. Editing a `SKILL.md` here edits the flake; run `nixos-rebuild switch` to activate. |
| `_claude/docs/*-CLAUDE.md` | Symlinks to repo CLAUDE.md files (root, dev, browsers, hyprland, utils). Edits write back to the flake source. |
| `.obsidian/` | **Do not touch.** Home Manager-owned. |

Anything else under the vault root is user-authored notes. Default link style: `[[wikilinks]]`, `newLinkFormat: shortest`.

## Frontmatter conventions

Every structural note (daily/meeting/project) has YAML frontmatter. Match the existing templates in `templates/` when creating new notes:

```yaml
---
date: YYYY-MM-DD          # ISO date
tags: [topic, subtype]    # lowercase, hyphen-separated
status: active|archived   # projects only
source: "https://..."     # clipped notes only
---
```

When you write a new note, always include frontmatter even if the user doesn't ask — `dataview` queries depend on it.

## Linking

- `[[note-name]]` — wiki-link to another note (by filename without extension).
- `[[note-name#heading]]` — link to a specific heading.
- `[[note-name#^block-id]]` — link to a block-ref (blocks tagged `^block-id`).
- `![[note-name]]` — transclude/embed the referenced note inline.
- `#tag` or `#nested/tag` — tags; also valid in frontmatter `tags: [...]`.

When creating new notes, look for existing notes that should link to this one (grep for related concepts) and add backlinks proactively — Obsidian's graph only shows what's explicitly linked.

## Templates

Insert via command palette → "Insert template" (Mod+P → "template"). The templater community plugin is enabled, so templates can contain `<% tp.* %>` blocks for dynamic content.

Authoring a new template: create the file in the flake at `modules/common/programs/notes/templates/<name>.md`, add an entry to the `home.file` list in `modules/common/programs/notes/obsidian.nix`, then `nixos-rebuild switch`. A template is just markdown with `{{date}}`, `{{title}}`, etc. placeholders (core Templates plugin) or `<% … %>` blocks (Templater plugin).

## Tasks

`obsidian-tasks-plugin` is enabled. Task syntax it recognizes:

```
- [ ] write report 📅 2026-05-01 ⏫ #work
- [x] done task ✅ 2026-04-18
```

Emojis carry meaning: 📅 due, 🛫 start, ⏳ scheduled, ⏫🔼🔽 priority, 🔁 recurrence, ✅ completion date. Query across the vault with a `tasks` code block:

````
```tasks
not done
due before tomorrow
group by tags
```
````

## Dataview queries

`dataview` plugin is enabled — treat frontmatter as a database.

````
```dataview
TABLE status, file.mtime AS "Modified"
FROM #project
WHERE status = "active"
SORT file.mtime DESC
```
````

Use inline `` `= this.file.name` `` expressions in a note to show computed values.

## Git

`obsidian-git` is configured with `autoSaveInterval = 10` (minutes) and commits to the submodule automatically. Implications:

- Don't leave half-written notes — they'll be committed.
- Large refactors (renaming/moving many notes) should be made as a batch, then the user can review the auto-commit.
- If you rename a file, Obsidian updates all `[[wikilinks]]` referencing it — do not manually sed through the vault.

## Common workflows

**Capture a quick thought**: create `_inbox/<slug>.md` with minimal frontmatter (`tags: [inbox]`, `date`) and the content. User triages later.

**Edit a skill via the vault**: open `_claude/skills/<name>/SKILL.md`, edit, save. The change lands in the flake immediately (symlink). Remind the user that `nixos-rebuild switch` reconnects Claude Code to the new skill.

**Edit a CLAUDE.md**: open `_claude/docs/<scope>-CLAUDE.md`, edit. Write-through to the flake. Commit the flake change normally.

**Add a new project**: create `<ProjectName>.md` at the vault root with `templates/project.md`'s frontmatter (status: active). Link it from the relevant index/MOC note if one exists.

**Find notes by tag**: use Obsidian's tag pane or grep: `grep -rl "#tagname" ~/killuanix/Notes --include="*.md"` (exclude `.obsidian`).

## What NOT to do

- Never edit anything under `~/killuanix/Notes/.obsidian/` — HM owns it, your edits will be wiped.
- Never commit files under `_claude/` or `_inbox/` inside the Notes submodule — they're gitignored for a reason (symlinks to flake / transient clipper output).
- Don't hand-maintain `community-plugins.json`, `appearance.json`, or `hotkeys.json` — those come from `modules/common/programs/notes/obsidian.nix`. To add a plugin, edit that file.
- Don't rename the vault folder. The Obsidian Web Clipper extension is configured to target `killuanix/Notes` by name.
