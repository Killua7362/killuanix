---
name: code-exploration
description: Prefer the code-index MCP server over grep/find/Glob whenever exploring, navigating, or answering questions about an indexed codebase. Use proactively when locating a symbol, finding where something is defined, understanding how a feature works, tracing callers/usages, or orienting in an unfamiliar repo — before reaching for Grep/Glob/Bash-find.
---

# Code Exploration — Index First, Grep Second

A Qdrant-backed semantic + symbol index is available via the `code-index` MCP server for many of the user's projects. Semantic search is faster and more accurate than `grep` when the question is conceptual ("how does X work", "where is error handling"), and symbol search is faster than `grep` when looking up a known name across a large tree. **Always prefer the index when it covers the current project.**

## Default flow for any code-exploration task

1. **Detect whether the current project is indexed.**
   - Check the working directory's `CLAUDE.md` first — individual projects pin their collection name there (that's the authoritative mapping when present).
   - If nothing is pinned, call `mcp__code-index__list_collections` and try to match by name against `cwd` or the path the user mentioned.
   - If ambiguous, call `mcp__code-index__get_index_status <collection>` on the likely candidate and check whether the `file_path`s inside match the directory you're working in.

2. **If indexed, use the index first.**
   - Natural-language / conceptual questions → `mcp__code-index__search_code` with the user's question (or a rephrased query) as the `query`. Pass the collection name.
   - Specific class / method / field / property / component names → `mcp__code-index__search_by_symbol`. Faster and more precise than semantic search when the user names something exact.
   - For ATG projects, `search_by_symbol` works on `.properties` keys too (e.g. `$class`, `$scope`, or a Nucleus component path) and on XML file stems.

3. **Verify before answering.**
   - The index returns chunks, not full files. After a hit, `Read` the file at the returned `start_line`–`end_line` range (plus surrounding context) before making claims, edits, or recommendations.
   - Always cite `file_path:line_number` in the reply so the user can jump there.

4. **Only fall back to Grep / Glob / `find` when:**
   - `list_collections` returns nothing, or no collection covers this directory.
   - Search results come back empty *and* you have a reason to believe the token is a literal (e.g. searching for a magic string, a log message, a config key not keyed by a real symbol name).
   - The target file type isn't one the indexer handles (see "Coverage" below).
   - The user explicitly asks for `grep` / a regex / literal-string search.

5. **If the project *is* indexed but seems stale** (user just edited files, or you just wrote some yourself), run `mcp__code-index__sync_index <path> <collection>` before searching. It's incremental — hashes files, only re-embeds changed ones, and drops deleted files. Much cheaper than a full reindex.

## Coverage

The indexer currently chunks:

| Extension | Chunking |
|---|---|
| `.java` | Tree-sitter AST — one chunk per class / interface / enum / record / method / constructor / annotation / field |
| `.properties` | One chunk per key (handles `#`/`!` comments and `\`-continuation lines; ATG `$class` / `$scope` keys surface as named chunks) |
| `.xml` | One whole-file chunk keyed on the file stem |

Everything else (`.jsp`, `.ts`, `.py`, `.md`, …) is invisible to the index — fall back to Grep/Glob for those.

Ignore dirs that the indexer skips (won't appear in results either): `.git`, `node_modules`, `__pycache__`, `.gradle`, `build`, `target`, `.idea`, `bin`, `out`.

## Query tips

- `search_code` responds well to *phrases*, not keyword lists. "how are orders persisted" beats "order persist save".
- For "who uses X" / "callers of X", run `search_by_symbol X` first to get the definition, then `search_code "calls to X"` or `search_code "uses X to …"` for call-sites. Grep is still often the right tool for exhaustive call-site enumeration — use it as the second pass after you understand the symbol.
- `search_code` results include a `Score`. Scores below ~0.5 are usually noise on this embedding model; don't over-weight them.
- Keep `limit` at the default (10) for a first pass. Bump it only if you need broader coverage.

## When NOT to use the index

- Exact-string / regex matches (error messages, TODO markers, literal URLs, log formats) → `Grep`.
- Listing files by name / glob (`**/*Controller.java`) → `Glob`.
- Reading a specific file you already know the path of → `Read`.
- Any project the user has not indexed.
- Right after a large refactor the user hasn't sync'd yet *and* they've asked you not to run `sync_index`.

## Summary rule

> If the current project is indexed and the question is "where / what / how" about code, **reach for `search_code` / `search_by_symbol` before reaching for `Grep` / `Glob` / `find`.**
