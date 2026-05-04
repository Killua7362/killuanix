---
name: memory-load
description: Load tagged memory files from the Notes/claude/memory/ vault on demand. Use when the user mentions a topic that might match a memory's `trigger:` keywords (e.g., "audio", "boeing", "firefox bookmarks"), explicitly invokes `@mem:<tag>` or `/memory <keyword>`, or when you're about to recommend an action and want to verify against stored feedback/project memories. Replaces always-on autoloading with tag/keyword-driven retrieval.
allowed-tools: Read, Glob, Grep, mcp__basic-memory__search_notes, mcp__basic-memory__read_note, mcp__basic-memory__list_directory
---

# memory-load — selective memory retrieval

The user's persistent memory lives at `~/killuanix/Notes/claude/memory/` as flat markdown files with YAML frontmatter. The MEMORY.md index (one-line pointers) is loaded every session. **Bodies are not** — pull them in only when relevant.

## When to use

1. **Explicit invocation** — the user types `@mem:<tag>`, `/memory <keyword>`, "what do you remember about X", "load my X memory", "check the memory for X".
2. **Implicit relevance** — the current prompt mentions a topic that overlaps with an entry in MEMORY.md or a `trigger:` keyword. Examples: user says "let's tweak pipewire" → load `project_handheld_pipewire_pin.md`; user says "I want firefox bookmarks via flake" → load `feedback_firefox_bookmarks.md`.
3. **Pre-recommendation guard** — before suggesting a mutation (file edit, config change, command), grep memory for a `feedback_*` entry that might forbid or guide the approach.

## How to use

Prefer the basic-memory MCP when available:

```
mcp__basic-memory__search_notes(query: "<keyword or trigger>")
mcp__basic-memory__read_note(name: "<filename>")
```

Fallback when basic-memory isn't connected:

```
Glob("/home/killua/killuanix/Notes/claude/memory/**/*.md")
Grep("<keyword>", path: "/home/killua/killuanix/Notes/claude/memory", output_mode: "files_with_matches")
Read(<matched file>)
```

## Loading discipline

- **Don't grep on the whole vault** (`Notes/`). Memory only lives under `Notes/claude/memory/`. The vault has many other notes (Boeing project docs, daily notes) that aren't memory.
- **Never load `_tags.md`** — it's a browsing aid for the user with empty `trigger:`. Skip it.
- **Echo what you loaded.** Before answering, list the memory file(s) you pulled in so the user can verify the right context arrived. Format: `Loaded memory: <filename> — <description>`.
- **Stop at 3 files.** If a search matches more than 3, summarise what you skipped and ask the user which to load. Loading too much defeats the purpose.

## Updating memory

Authoring rules live in `Notes/claude/memory/README.md`. Read that file before any write. Key points:

- Filenames: `<type>_<short_slug>.md` where type ∈ `user|feedback|project|reference|domain`.
- Required frontmatter: `name`, `description`, `type`, `tags`, `trigger`, `created`, `updated` (absolute dates).
- Always update `MEMORY.md` (the index) with a one-line pointer when you create a new memory.
- Use `mcp__basic-memory__edit_note` with `operation: append` or `operation: replace_section` for body edits. Avoid `find_replace` against the YAML frontmatter — known edge cases.

## Don't duplicate work

The `obsidian-vault` skill (in this same directory) covers vault navigation, frontmatter conventions, and template usage for the broader vault. This skill is purely about the `claude/memory/` subtree. If the user is asking about Boeing project notes or daily notes, hand off to `obsidian-vault` instead.
