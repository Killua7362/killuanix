---
name: code-search
description: Search indexed codebases using semantic search and AST-based code index. Use when the user asks about code structure, wants to find classes/methods/functions, asks "where is X defined", "how does X work", or wants to understand a codebase that has been indexed in Qdrant.
allowed-tools: mcp__code-index__search_code, mcp__code-index__search_by_symbol, mcp__code-index__index_codebase, mcp__code-index__sync_index, mcp__code-index__get_index_status, mcp__code-index__list_collections, mcp__code-index__stop_indexing, mcp__code-index__clear_index
---

# Code Search — Semantic Codebase Search

You have access to a code indexing system via the `code-index` MCP server. Use it automatically when the user asks questions about indexed codebases.

## Available tools

| Tool | When to use |
|---|---|
| `mcp__code-index__search_code` | User asks a natural language question about code ("how does authentication work", "find error handling logic", "where are database queries") |
| `mcp__code-index__search_by_symbol` | User mentions a specific class, method, or field name ("find UserService", "where is handleRequest defined") |
| `mcp__code-index__index_codebase` | User wants to do a full index of a new project or complete re-index |
| `mcp__code-index__sync_index` | User changed code and wants to update the index, or says "sync", "update index", "re-index changes". Much faster than full index — only processes changed/new/deleted files |
| `mcp__code-index__get_index_status` | User asks about what's indexed or collection stats |
| `mcp__code-index__list_collections` | User asks what codebases are available/indexed |
| `mcp__code-index__stop_indexing` | User wants to cancel a running indexing operation |
| `mcp__code-index__clear_index` | User wants to remove an indexed collection |

## How to use

- When the user asks about code in an indexed project, call `mcp__code-index__search_code` with their question as the query. Use the appropriate collection name.
- When results come back, read the actual source files for full context before answering — the indexed chunks may be partial.
- If the user mentions a specific symbol name, prefer `mcp__code-index__search_by_symbol` for precise results.
- Combine multiple searches if needed to build a complete picture.
- Always mention which files the answer came from so the user can navigate there.

## Known collections

Check `mcp__code-index__list_collections` if unsure. The user may have indexed projects with custom collection names.

## Indexing new projects

When the user says "index this project" or "add this codebase":
1. Ask which directory to index (or use the current working directory)
2. Suggest a meaningful collection name based on the project
3. Call `mcp__code-index__index_codebase` with the path and collection name
4. Currently supports **Java** files only (tree-sitter AST parsing)

## Updating after code changes

When the user says "sync index", "update index", "re-index", or mentions they changed code:
1. Use `mcp__code-index__sync_index` (NOT `index_codebase`) — it's incremental
2. It compares file hashes, skips unchanged files, re-indexes modified ones, and removes deleted ones
3. Prefer `sync_index` over `index_codebase` whenever a collection already exists
