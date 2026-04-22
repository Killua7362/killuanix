---
name: obsidian-clipper
description: Triage and process web-clipped articles saved by the Obsidian Web Clipper Firefox extension. Use when the user mentions a clipped page, an article they saved, wants to process their inbox, clean up frontmatter on clipped notes, or turn a clip into a proper reading/reference note.
---

# Obsidian Clipper — Inbox triage

The Obsidian Web Clipper Firefox extension drops web pages into `~/killuanix/Notes/_inbox/` as markdown files. Each clip starts with the template seeded from `modules/common/programs/notes/templates/clipper.md` — a YAML frontmatter block (`source`, `author`, `published`, `clipped`, `tags: [inbox, clipped]`) followed by the clipped body.

Your job is to take a clip (or a batch of them) and turn it into a useful, findable note in the vault.

## Triage steps

Given a file under `_inbox/`:

1. **Read the clip** — check the frontmatter for `source` (URL), `author`, `published`. Skim the body.
2. **Clean the body** if the clip is noisy: drop nav/footer detritus, collapse repeated whitespace, fix heading levels. Preserve code blocks and images verbatim.
3. **Pick a destination folder** based on content type:
   - `reading/` — articles, essays, long-form
   - `reference/` — docs, tutorials, API references, recipes
   - `research/<topic>/` — multiple related clips on a theme
   - If the topic matches an existing project or MOC (Map of Content), drop it beside that project's folder.
4. **Replace tags**: drop `inbox` and `clipped`, add topical tags (`#programming/rust`, `#reading/productivity`, etc.). Use the vault's existing tag conventions — grep for nearby precedents before inventing new ones.
5. **Add backlinks**: search the vault for existing notes that reference the same topic and add `[[wikilinks]]` from them to the new note (or from the new note to them). Two-way linking where natural.
6. **Rename the file** to a slug matching the title: `kebab-case-title.md`. Preserve only the meaningful stem (drop "How To" etc. if redundant).
7. **Move the file** out of `_inbox/` into the chosen folder. Obsidian auto-updates any wikilinks on rename/move — but since this note is fresh, there are none yet.

## Example

Input: `_inbox/untitled-1713654321.md`

```markdown
---
source: "https://rust-unofficial.github.io/too-many-lists/"
author: "Ryan Levick"
published: ""
clipped: "2026-04-19"
tags: [inbox, clipped]
---
# Learn Rust With Entirely Too Many Linked Lists

[...body...]
```

Action: rename → `reading/too-many-linked-lists.md`, update tags to `[reading, rust, data-structures]`, add `[[rust-learning-resources]]` backlink if a Rust MOC exists, commit body to stable Markdown (drop nav cruft).

## When to leave something alone

- If the user says "just capture, I'll triage later" — leave the clip in `_inbox/`.
- If the clip is paywalled/half-rendered (`body` is mostly login walls) — flag it back to the user instead of trying to salvage.
- If the clip duplicates an existing vault note — ask whether to merge or keep as a second source.

## Batch mode

If the user asks to "process the inbox": list all files in `~/killuanix/Notes/_inbox/`, propose a triage plan (destination folder + tags) as a table, and wait for confirmation before moving files. Don't silently move 20 clips.

## Cross-reference

For general vault conventions (frontmatter, linking, templates), see the `obsidian-vault` skill.
