"""
Code Index MCP Server — Tree-sitter AST indexing with NVIDIA embeddings and Qdrant.
"""

import os
import hashlib
import logging
import threading
from pathlib import Path
from dataclasses import dataclass, field

import httpx
import tree_sitter_java as tsjava
from tree_sitter import Language, Parser, Node
from qdrant_client import QdrantClient
from qdrant_client.models import (
    Distance,
    FieldCondition,
    Filter,
    HnswConfigDiff,
    MatchValue,
    OptimizersConfigDiff,
    PointStruct,
    ScalarQuantization,
    ScalarQuantizationConfig,
    ScalarType,
    VectorParams,
    VectorParamsDiff,
)
from mcp.server.fastmcp import FastMCP

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("code-index-mcp")

# ── Configuration ──────────────────────────────────────────────────────

def _read_secret(env_file_key: str, env_key: str, default: str = "") -> str:
    """Read a secret from a file path env var, falling back to direct env var."""
    file_path = os.environ.get(env_file_key)
    if file_path:
        p = Path(file_path)
        if p.exists():
            return p.read_text().strip()
    return os.environ.get(env_key, default)


QDRANT_URL = _read_secret("QDRANT_URL_FILE", "QDRANT_URL", "http://127.0.0.1:6333")
QDRANT_API_KEY = _read_secret("QDRANT_API_KEY_FILE", "QDRANT_API_KEY", "")
NVIDIA_API_URL = "https://integrate.api.nvidia.com/v1/embeddings"
NVIDIA_MODEL = "nvidia/llama-nemotron-embed-1b-v2"
EMBEDDING_DIM = 2048  # llama-nemotron-embed-1b-v2 output dimension
BATCH_SIZE = 50  # NVIDIA API batch limit

JAVA_LANGUAGE = Language(tsjava.language())

# AST node types to extract as indexable chunks
JAVA_CHUNK_TYPES = frozenset(
    {
        "class_declaration",
        "interface_declaration",
        "enum_declaration",
        "record_declaration",
        "method_declaration",
        "constructor_declaration",
        "annotation_type_declaration",
        "field_declaration",
    }
)

# File extensions per language (extensible for future grammars)
LANGUAGE_EXTENSIONS = {
    "java": {".java"},
    "properties": {".properties"},
    "xml": {".xml"},
}


def _get_nvidia_api_key() -> str:
    key = _read_secret("NVIDIA_API_KEY_FILE", "NVIDIA_API_KEY")
    if not key:
        raise RuntimeError(
            "NVIDIA API key not found. Set NVIDIA_API_KEY or NVIDIA_API_KEY_FILE."
        )
    return key


# ── AST Chunking ──────────────────────────────────────────────────────


@dataclass
class CodeChunk:
    file_path: str
    language: str
    node_type: str
    name: str
    start_line: int
    end_line: int
    text: str
    parent_name: str = ""
    file_hash: str = ""


def _node_name(node: Node) -> str:
    """Extract the identifier name from an AST node."""
    for child in node.children:
        if child.type == "identifier":
            return child.text.decode("utf-8")
    return "<anonymous>"


def _find_parent_class(node: Node) -> str:
    """Walk up to find the enclosing class/interface name."""
    current = node.parent
    while current:
        if current.type in ("class_declaration", "interface_declaration", "enum_declaration"):
            return _node_name(current)
        current = current.parent
    return ""


def parse_java_file(file_path: Path) -> list[CodeChunk]:
    """Parse a Java file into AST-based code chunks."""
    source = file_path.read_bytes()
    file_hash = hashlib.sha256(source).hexdigest()

    parser = Parser(JAVA_LANGUAGE)
    tree = parser.parse(source)

    chunks: list[CodeChunk] = []

    def visit(node: Node) -> None:
        if node.type in JAVA_CHUNK_TYPES:
            text = node.text.decode("utf-8")
            chunks.append(
                CodeChunk(
                    file_path=str(file_path),
                    language="java",
                    node_type=node.type,
                    name=_node_name(node),
                    start_line=node.start_point[0] + 1,
                    end_line=node.end_point[0] + 1,
                    text=text,
                    parent_name=_find_parent_class(node),
                    file_hash=file_hash,
                )
            )
        for child in node.children:
            visit(child)

    visit(tree.root_node)
    return chunks


def _extract_properties_key(line: str) -> str:
    """Extract the key from a .properties line, handling backslash escapes."""
    buf: list[str] = []
    i = 0
    while i < len(line):
        ch = line[i]
        if ch == "\\" and i + 1 < len(line):
            buf.append(line[i + 1])
            i += 2
            continue
        if ch in ("=", ":") or ch.isspace():
            break
        buf.append(ch)
        i += 1
    return "".join(buf) or "<anonymous>"


def parse_properties_file(file_path: Path) -> list[CodeChunk]:
    """Parse a .properties file into one chunk per key. Handles comments (# / !)
    and backslash line continuations."""
    source_bytes = file_path.read_bytes()
    file_hash = hashlib.sha256(source_bytes).hexdigest()
    text = source_bytes.decode("utf-8", errors="replace")
    lines = text.splitlines()

    chunks: list[CodeChunk] = []
    i = 0
    while i < len(lines):
        raw = lines[i]
        stripped = raw.lstrip()
        if not stripped or stripped.startswith("#") or stripped.startswith("!"):
            i += 1
            continue

        start_line = i + 1
        buf = raw
        while buf.rstrip().endswith("\\") and i + 1 < len(lines):
            i += 1
            buf = buf.rstrip()[:-1] + "\n" + lines[i]
        end_line = i + 1

        key = _extract_properties_key(stripped)
        chunks.append(
            CodeChunk(
                file_path=str(file_path),
                language="properties",
                node_type="property",
                name=key,
                start_line=start_line,
                end_line=end_line,
                text=buf,
                file_hash=file_hash,
            )
        )
        i += 1
    return chunks


def parse_xml_file(file_path: Path) -> list[CodeChunk]:
    """Parse an XML file as a single whole-file chunk."""
    source_bytes = file_path.read_bytes()
    file_hash = hashlib.sha256(source_bytes).hexdigest()
    text = source_bytes.decode("utf-8", errors="replace")
    line_count = text.count("\n") + 1
    return [
        CodeChunk(
            file_path=str(file_path),
            language="xml",
            node_type="file",
            name=file_path.stem,
            start_line=1,
            end_line=line_count,
            text=text,
            file_hash=file_hash,
        )
    ]


def collect_files(directory: Path, extensions: set[str]) -> list[Path]:
    """Recursively collect files matching extensions, respecting common ignores."""
    ignore_dirs = {".git", "node_modules", "__pycache__", ".gradle", "build", "target", ".idea", "bin", "out"}
    files: list[Path] = []
    for item in directory.rglob("*"):
        if any(part in ignore_dirs for part in item.parts):
            continue
        if item.is_file() and item.suffix in extensions:
            files.append(item)
    return sorted(files)


# ── Embedding ─────────────────────────────────────────────────────────


def embed_texts(texts: list[str], input_type: str = "passage") -> list[list[float]]:
    """Call NVIDIA API to embed a batch of texts."""
    api_key = _get_nvidia_api_key()
    all_embeddings: list[list[float]] = []

    for i in range(0, len(texts), BATCH_SIZE):
        batch = texts[i : i + BATCH_SIZE]
        # Truncate very long texts to avoid API limits
        batch = [t[:8192] for t in batch]

        resp = httpx.post(
            NVIDIA_API_URL,
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
            },
            json={
                "model": NVIDIA_MODEL,
                "input": batch,
                "input_type": input_type,
                "encoding_format": "float",
            },
            timeout=60.0,
        )
        resp.raise_for_status()
        data = resp.json()
        # Sort by index to preserve order
        sorted_embs = sorted(data["data"], key=lambda x: x["index"])
        all_embeddings.extend([e["embedding"] for e in sorted_embs])

    return all_embeddings


# ── Qdrant Operations ────────────────────────────────────────────────


def get_qdrant() -> QdrantClient:
    return QdrantClient(url=QDRANT_URL, api_key=QDRANT_API_KEY or None)


# Memory-efficient defaults for collections created by this indexer:
#   - vectors.on_disk=True       → raw vectors are mmap'd, kernel manages cache
#   - hnsw_config.on_disk=True   → HNSW graph spilled to disk
#   - int8 scalar quantization   → ~4x smaller hot working set;
#                                  always_ram=True keeps the quantized copy
#                                  resident so search stays fast
#   - memmap_threshold=20000     → segments above this point count are mmap'd
_MEMMAP_THRESHOLD = 20000

_QUANTIZATION_CONFIG = ScalarQuantization(
    scalar=ScalarQuantizationConfig(type=ScalarType.INT8, always_ram=True),
)


def ensure_collection(client: QdrantClient, name: str) -> None:
    collections = [c.name for c in client.get_collections().collections]
    if name not in collections:
        client.create_collection(
            collection_name=name,
            vectors_config=VectorParams(
                size=EMBEDDING_DIM,
                distance=Distance.COSINE,
                on_disk=True,
            ),
            hnsw_config=HnswConfigDiff(on_disk=True),
            quantization_config=_QUANTIZATION_CONFIG,
            optimizers_config=OptimizersConfigDiff(memmap_threshold=_MEMMAP_THRESHOLD),
        )
        logger.info(f"Created collection: {name}")


def get_indexed_file_hashes(client: QdrantClient, collection: str) -> dict[str, str]:
    """Scroll through the collection and return {file_path: file_hash} for all indexed files."""
    file_hashes: dict[str, str] = {}
    offset = None
    while True:
        points, offset = client.scroll(
            collection_name=collection,
            limit=100,
            offset=offset,
            with_payload=["file_path", "file_hash"],
        )
        for point in points:
            fp = point.payload.get("file_path", "")
            fh = point.payload.get("file_hash", "")
            if fp and fh:
                file_hashes[fp] = fh
        if offset is None:
            break
    return file_hashes


def delete_chunks_for_files(client: QdrantClient, collection: str, file_paths: set[str]) -> int:
    """Delete all chunks belonging to the given file paths. Returns count of files cleaned."""
    deleted = 0
    for fp in file_paths:
        client.delete(
            collection_name=collection,
            points_selector=Filter(
                must=[FieldCondition(key="file_path", match=MatchValue(value=fp))]
            ),
        )
        deleted += 1
    return deleted


def hash_file(file_path: Path) -> str:
    """Compute SHA-256 hash of a file."""
    return hashlib.sha256(file_path.read_bytes()).hexdigest()


def upsert_chunks(
    client: QdrantClient,
    collection: str,
    chunks: list[CodeChunk],
    embeddings: list[list[float]],
) -> None:
    points = []
    for i, (chunk, embedding) in enumerate(zip(chunks, embeddings)):
        point_id = hashlib.md5(
            f"{chunk.file_path}:{chunk.start_line}:{chunk.name}".encode()
        ).hexdigest()
        # Qdrant needs UUID-like or integer IDs; use first 32 hex chars as UUID
        point_id_str = f"{point_id[:8]}-{point_id[8:12]}-{point_id[12:16]}-{point_id[16:20]}-{point_id[20:32]}"

        points.append(
            PointStruct(
                id=point_id_str,
                vector=embedding,
                payload={
                    "file_path": chunk.file_path,
                    "language": chunk.language,
                    "node_type": chunk.node_type,
                    "name": chunk.name,
                    "parent_name": chunk.parent_name,
                    "start_line": chunk.start_line,
                    "end_line": chunk.end_line,
                    "text": chunk.text,
                    "file_hash": chunk.file_hash,
                },
            )
        )

    # Upsert in batches of 100
    for i in range(0, len(points), 100):
        client.upsert(collection_name=collection, points=points[i : i + 100])


# ── Indexing State ────────────────────────────────────────────────────

_cancel_event = threading.Event()


# ── MCP Server ────────────────────────────────────────────────────────

mcp = FastMCP("code-index")


@mcp.tool()
def stop_indexing() -> str:
    """Stop any currently running indexing operation. Already-indexed chunks are kept in Qdrant."""
    _cancel_event.set()
    return "Stop signal sent. Indexing will halt after the current batch finishes."


def _do_index(
    client: QdrantClient,
    collection: str,
    files: list[Path],
    skip_hashes: dict[str, str] | None = None,
) -> tuple[int, int, int, list[str], bool]:
    """Core indexing loop. Returns (files_indexed, chunks_indexed, files_skipped, errors, cancelled)."""
    total_chunks = 0
    total_files = 0
    skipped = 0
    errors: list[str] = []
    cancelled = False
    pending_chunks: list[CodeChunk] = []

    for file_path in files:
        if _cancel_event.is_set():
            cancelled = True
            break

        try:
            suffix = file_path.suffix
            if suffix in LANGUAGE_EXTENSIONS["java"]:
                parser_fn = parse_java_file
            elif suffix in LANGUAGE_EXTENSIONS["properties"]:
                parser_fn = parse_properties_file
            elif suffix in LANGUAGE_EXTENSIONS["xml"]:
                parser_fn = parse_xml_file
            else:
                continue

            # Skip unchanged files if we have existing hashes
            if skip_hashes is not None:
                current_hash = hash_file(file_path)
                existing_hash = skip_hashes.get(str(file_path))
                if existing_hash == current_hash:
                    skipped += 1
                    continue

            chunks = parser_fn(file_path)
            pending_chunks.extend(chunks)
            total_files += 1

            # Embed and upsert in batches
            if len(pending_chunks) >= BATCH_SIZE:
                if _cancel_event.is_set():
                    cancelled = True
                    break
                texts = [c.text for c in pending_chunks]
                embeddings = embed_texts(texts, input_type="passage")
                upsert_chunks(client, collection, pending_chunks, embeddings)
                total_chunks += len(pending_chunks)
                pending_chunks = []

        except Exception as e:
            errors.append(f"{file_path}: {e}")

    # Flush remaining (unless cancelled)
    if pending_chunks and not _cancel_event.is_set():
        try:
            texts = [c.text for c in pending_chunks]
            embeddings = embed_texts(texts, input_type="passage")
            upsert_chunks(client, collection, pending_chunks, embeddings)
            total_chunks += len(pending_chunks)
        except Exception as e:
            errors.append(f"Final batch: {e}")

    return total_files, total_chunks, skipped, errors, cancelled


@mcp.tool()
def index_codebase(path: str, collection: str = "default") -> str:
    """Full index of a codebase directory. Parses Java files using tree-sitter AST,
    generates embeddings via NVIDIA API, and stores in Qdrant.
    For incremental updates after code changes, use sync_index instead.
    Use stop_indexing to cancel a running operation.

    Args:
        path: Absolute path to the codebase directory to index.
        collection: Qdrant collection name (default: "default").
    """
    _cancel_event.clear()

    directory = Path(path).resolve()
    if not directory.is_dir():
        return f"Error: {path} is not a directory"

    client = get_qdrant()
    ensure_collection(client, collection)

    all_extensions: set[str] = set()
    for exts in LANGUAGE_EXTENSIONS.values():
        all_extensions.update(exts)

    files = collect_files(directory, all_extensions)
    if not files:
        return f"No supported files found in {path}"

    total_files, total_chunks, _, errors, cancelled = _do_index(client, collection, files)

    status = "CANCELLED" if cancelled else "Completed"
    result = f"**{status}** — Indexed {total_files} files, {total_chunks} chunks into collection '{collection}'"
    if errors:
        result += f"\n\nErrors ({len(errors)}):\n" + "\n".join(errors[:10])
    return result


@mcp.tool()
def sync_index(path: str, collection: str = "default") -> str:
    """Incrementally sync an already-indexed codebase. Only processes files that
    have changed since last indexing (based on SHA-256 file hash). Also removes
    chunks from deleted files. Much faster than a full re-index.

    Args:
        path: Absolute path to the codebase directory.
        collection: Qdrant collection name (default: "default").
    """
    _cancel_event.clear()

    directory = Path(path).resolve()
    if not directory.is_dir():
        return f"Error: {path} is not a directory"

    client = get_qdrant()

    # Check collection exists
    try:
        client.get_collection(collection_name=collection)
    except Exception:
        return f"Collection '{collection}' does not exist. Use index_codebase for the first full index."

    all_extensions: set[str] = set()
    for exts in LANGUAGE_EXTENSIONS.values():
        all_extensions.update(exts)

    # Get existing file hashes from Qdrant
    logger.info("Fetching existing file hashes from Qdrant...")
    indexed_hashes = get_indexed_file_hashes(client, collection)
    indexed_files = set(indexed_hashes.keys())

    # Collect current files on disk
    current_files = collect_files(directory, all_extensions)
    current_file_strs = {str(f) for f in current_files}

    # Find deleted files (in Qdrant but no longer on disk)
    deleted_files = indexed_files - current_file_strs
    deleted_count = 0
    if deleted_files:
        logger.info(f"Removing {len(deleted_files)} deleted files from index...")
        deleted_count = delete_chunks_for_files(client, collection, deleted_files)

    if _cancel_event.is_set():
        return f"**CANCELLED** — Removed {deleted_count} deleted files before cancellation."

    # Find changed files: hash each current file and compare
    changed_files: list[Path] = []
    new_files: list[Path] = []
    unchanged = 0

    for file_path in current_files:
        if _cancel_event.is_set():
            break
        fp_str = str(file_path)
        current_hash = hash_file(file_path)
        existing_hash = indexed_hashes.get(fp_str)

        if existing_hash is None:
            new_files.append(file_path)
        elif existing_hash != current_hash:
            changed_files.append(file_path)
        else:
            unchanged += 1

    # Delete old chunks for changed files before re-indexing them
    if changed_files and not _cancel_event.is_set():
        logger.info(f"Removing old chunks for {len(changed_files)} changed files...")
        delete_chunks_for_files(client, collection, {str(f) for f in changed_files})

    # Index new + changed files
    files_to_index = new_files + changed_files
    if not files_to_index:
        return (
            f"**Up to date** — No changes detected.\n"
            f"**Unchanged:** {unchanged} files\n"
            f"**Deleted:** {deleted_count} files removed from index"
        )

    logger.info(f"Indexing {len(new_files)} new + {len(changed_files)} changed files...")
    total_files, total_chunks, _, errors, cancelled = _do_index(
        client, collection, files_to_index
    )

    status = "CANCELLED" if cancelled else "Completed"
    result = (
        f"**{status}** — Synced collection '{collection}'\n"
        f"**New:** {len(new_files)} files\n"
        f"**Changed:** {len(changed_files)} files re-indexed\n"
        f"**Unchanged:** {unchanged} files skipped\n"
        f"**Deleted:** {deleted_count} files removed\n"
        f"**Total chunks upserted:** {total_chunks}"
    )
    if errors:
        result += f"\n\nErrors ({len(errors)}):\n" + "\n".join(errors[:10])
    return result


@mcp.tool()
def search_code(query: str, collection: str = "default", limit: int = 10) -> str:
    """Semantic search across indexed code using natural language.

    Args:
        query: Natural language search query (e.g. "authentication handler", "database connection pool").
        collection: Qdrant collection to search (default: "default").
        limit: Maximum number of results to return.
    """
    client = get_qdrant()
    query_embedding = embed_texts([query], input_type="query")[0]

    results = client.query_points(
        collection_name=collection,
        query=query_embedding,
        limit=limit,
        with_payload=True,
    )

    if not results.points:
        return "No results found."

    output_parts: list[str] = []
    for point in results.points:
        p = point.payload
        output_parts.append(
            f"## {p['node_type']}: {p['name']}"
            + (f" (in {p['parent_name']})" if p.get("parent_name") else "")
            + f"\n**File:** {p['file_path']}:{p['start_line']}-{p['end_line']}"
            + f" | **Score:** {point.score:.4f}"
            + f"\n```{p.get('language', '')}\n{p['text']}\n```\n"
        )

    return "\n".join(output_parts)


@mcp.tool()
def search_by_symbol(
    symbol: str, collection: str = "default", limit: int = 10
) -> str:
    """Search for a specific symbol (class, method, field) by name.

    Args:
        symbol: Symbol name to search for (e.g. "UserService", "handleRequest").
        collection: Qdrant collection to search (default: "default").
        limit: Maximum number of results.
    """
    client = get_qdrant()

    # Combine vector search with name filter for best results
    query_embedding = embed_texts([symbol], input_type="query")[0]

    results = client.query_points(
        collection_name=collection,
        query=query_embedding,
        query_filter=Filter(
            should=[
                FieldCondition(key="name", match=MatchValue(value=symbol)),
                FieldCondition(key="parent_name", match=MatchValue(value=symbol)),
            ]
        ),
        limit=limit,
        with_payload=True,
    )

    if not results.points:
        return f"No symbol '{symbol}' found."

    output_parts: list[str] = []
    for point in results.points:
        p = point.payload
        output_parts.append(
            f"## {p['node_type']}: {p['name']}"
            + (f" (in {p['parent_name']})" if p.get("parent_name") else "")
            + f"\n**File:** {p['file_path']}:{p['start_line']}-{p['end_line']}"
            + f"\n```{p.get('language', '')}\n{p['text']}\n```\n"
        )

    return "\n".join(output_parts)


@mcp.tool()
def get_index_status(collection: str = "default") -> str:
    """Get the status of an indexed collection — point count, files indexed, etc.

    Args:
        collection: Collection name to check (default: "default").
    """
    client = get_qdrant()

    try:
        info = client.get_collection(collection_name=collection)
    except Exception:
        return f"Collection '{collection}' does not exist."

    # Get unique file count by scrolling payloads
    files: set[str] = set()
    offset = None
    while True:
        result = client.scroll(
            collection_name=collection,
            limit=100,
            offset=offset,
            with_payload=["file_path"],
        )
        points, offset = result
        for point in points:
            files.add(point.payload["file_path"])
        if offset is None:
            break

    return (
        f"**Collection:** {collection}\n"
        f"**Status:** {info.status}\n"
        f"**Total chunks:** {info.points_count}\n"
        f"**Unique files:** {len(files)}\n"
        f"**Vector size:** {info.config.params.vectors.size}\n"
        f"**Distance:** {info.config.params.vectors.distance}"
    )


@mcp.tool()
def list_collections() -> str:
    """List all indexed collections in Qdrant."""
    client = get_qdrant()
    collections = client.get_collections().collections

    if not collections:
        return "No collections found."

    parts: list[str] = []
    for c in collections:
        parts.append(f"- **{c.name}**")

    return "## Collections\n" + "\n".join(parts)


@mcp.tool()
def optimize_collection(collection: str = "default") -> str:
    """Apply memory-efficient settings to an existing Qdrant collection without
    re-indexing: move vectors and the HNSW graph to disk (kernel-managed mmap),
    enable int8 scalar quantization with the quantized copy pinned in RAM, and
    lower memmap_threshold so segments are spilled to disk on the next merge.

    Args:
        collection: Collection name to optimize (default: "default").
    """
    client = get_qdrant()
    try:
        client.update_collection(
            collection_name=collection,
            vectors_config={"": VectorParamsDiff(on_disk=True)},
            hnsw_config=HnswConfigDiff(on_disk=True),
            quantization_config=_QUANTIZATION_CONFIG,
            optimizers_config=OptimizersConfigDiff(memmap_threshold=_MEMMAP_THRESHOLD),
        )
    except Exception as e:
        return f"Error updating collection '{collection}': {e}"

    return (
        f"Applied memory-efficient settings to '{collection}'. "
        "Existing in-RAM segments will be rewritten on the next optimizer "
        "merge — RSS will drop gradually, not instantly."
    )


@mcp.tool()
def clear_index(collection: str = "default") -> str:
    """Delete an indexed collection and all its data.

    Args:
        collection: Collection name to delete (default: "default").
    """
    client = get_qdrant()
    try:
        client.delete_collection(collection_name=collection)
        return f"Collection '{collection}' deleted."
    except Exception as e:
        return f"Error deleting collection: {e}"


def main():
    mcp.run(transport="stdio")


if __name__ == "__main__":
    main()
