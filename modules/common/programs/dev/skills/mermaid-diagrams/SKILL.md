---
name: mermaid-diagrams
description: Author, render, and preview Mermaid diagrams. Use when the user asks for a flowchart, sequence diagram, ER diagram, Gantt chart, state machine, class diagram, user journey, mindmap, or any Mermaid syntax; when creating/editing .mmd or .mermaid files; when embedding mermaid code fences in markdown that need validation or rendering; or when they want to preview a diagram live in the browser.
---

# Mermaid Diagrams

Two tools are available for Mermaid work on this system:

| Tool | Where | What it does |
|---|---|---|
| **`mermaid` MCP server** | stdio, always available to Claude | Validates + renders Mermaid source to SVG/PNG via puppeteer. Call the `generate` tool with `code` and an output path. |
| **`mmdc` CLI** | Shell (`$MERMAID_CLI` env var also points here) | `mmdc -i diagram.mmd -o diagram.svg` for batch rendering in scripts or CI. |
| **Mermaid Live Editor** | Browser at <http://localhost:8898> (containerised) | Interactive playground. Launch it from the user's app launcher or run `mermaid-live` in a shell. |

## File conventions

- Save standalone diagrams as `diagram-name.mmd` next to the code or docs they relate to.
- For markdown with inline diagrams, prefer ```` ```mermaid ```` fenced blocks — Obsidian, GitHub, and the user's markdown renderers all handle these natively.
- When a rendered image is needed as an artifact, render once with the MCP `generate` tool and commit both the `.mmd` source and the output next to each other.

## Picking a diagram type

| User intent | Mermaid type |
|---|---|
| "How does request X flow?" / API call chain | `sequenceDiagram` |
| High-level architecture / components | `flowchart` (LR or TD) |
| State machine / lifecycle | `stateDiagram-v2` |
| Data model / schema | `erDiagram` |
| Timeline / schedule | `gantt` |
| Class relationships (OO) | `classDiagram` |
| User flow with stages | `journey` |
| Hierarchical brainstorm | `mindmap` |

## Workflow

1. Draft the diagram in Mermaid syntax inside the relevant file (code comment, docs, or standalone `.mmd`).
2. Call the `mermaid` MCP `generate` tool to validate + render. Puppeteer errors usually mean syntax errors — fix the source, don't silence them.
3. If the user wants to iterate visually, point them at <http://localhost:8898> — they can paste the source, tweak, and copy back.
4. Keep diagrams small. If a flowchart has >20 nodes, split it into linked sub-diagrams or switch representation.

## Don'ts

- Don't embed raw SVG/PNG data in markdown when the `.mmd` source is available — always link the rendered file.
- Don't hand-write `<svg>` for things Mermaid can express. The grammar is stable and supported everywhere.
- Don't assume the user has run the container — if rendering fails with ECONNREFUSED on :8898, they simply haven't opened the browser yet; the MCP `generate` tool works independently.
