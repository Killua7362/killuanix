---
name: excalidraw-sketches
description: Create and edit Excalidraw sketches, whiteboard-style diagrams, and freeform visual notes. Use when the user asks for a sketch, whiteboard diagram, hand-drawn look, wireframe, architecture sketch, or any .excalidraw file; when they want to draft a visual that feels informal; or when a rigid diagram format (Mermaid, C4) doesn't fit the fuzzy, exploratory style of the request.
---

# Excalidraw Sketches

Excalidraw is the right tool when the user wants a loose, hand-drawn visual — think whiteboarding, wireframes, napkin sketches. For structured diagrams (sequence, flow, ER), reach for the `mermaid-diagrams` skill instead.

## Tools

| Tool | What it does |
|---|---|
| **`excalidraw` MCP server** | 26+ tools: `add_element`, `update_element`, `delete_element`, `get_element`, `batch_create_elements`, `export_scene`, `import_scene`, `export_to_image`, `clear_canvas`. Maintains a live canvas on `http://localhost:3031` (PORT env in mcp-servers.nix). |
| **Excalidraw web UI** | Browser at <http://localhost:8899> (containerised). Launch with `excalidraw` from the shell or the app launcher. |

## File format

`.excalidraw` files are plain JSON:

```
{
  "type": "excalidraw",
  "version": 2,
  "source": "https://excalidraw.com",
  "elements": [ { "id": "...", "type": "rectangle", "x": 100, "y": 100, ... } ],
  "appState": { "gridSize": 20, "viewBackgroundColor": "#ffffff", ... },
  "files": {}
}
```

You can generate or edit them as raw JSON if the MCP is unavailable — the schema is documented at <https://docs.excalidraw.com/docs/codebase/json-schema>.

## Workflow

1. Use `batch_create_elements` when drafting from scratch — it's dramatically faster than one-at-a-time `add_element` calls for multi-shape scenes.
2. Call `export_scene` to write the canvas to a `.excalidraw` file on disk (pass an absolute path).
3. Tell the user the file path and mention they can open it at <http://localhost:8899> by using "Open" inside the UI, or by double-clicking the file if a handler is registered.
4. For a quick PNG/SVG for inclusion in docs, use `export_to_image` with `{ "mimeType": "image/svg+xml" }` or `"image/png"`.

## Picking element types

| Intent | Element |
|---|---|
| Box with label | `rectangle` + `text` (group them) |
| Decision point | `diamond` |
| Entity or actor | `ellipse` with label |
| Connection | `arrow` (with `startBinding`/`endBinding` pointing at element IDs) |
| Annotation / note | `text` alone |
| Freehand | `freedraw` (arrays of `points`) |

Default to rounded rectangles (`roundness: { type: 3 }`) and the "sloppiness: 1" artistic look — that's Excalidraw's visual identity. Use `sloppiness: 0` only when the user explicitly asks for sharp geometry.

## Don'ts

- Don't fight the tool — if the diagram is actually a flowchart or a sequence diagram, use Mermaid. Excalidraw is for when structure is secondary to feel.
- Don't forget `appState.viewBackgroundColor` when exporting: leaving it null gives a transparent background, which renders invisibly on dark-theme viewers.
- Don't call `clear_canvas` without confirming — it's destructive and the MCP doesn't auto-backup.
