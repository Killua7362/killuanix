"""`manifest-hash` subcommand."""
import hashlib
import json
from pathlib import Path

from lib.manifest import _sha256_file, _walk_files


def cmd_manifest_hash(args):
    """Hash the project's files/ tree: sha256 over (path, content-sha) pairs."""
    root = Path(args.root).resolve()
    files_dir = root / "files"
    if not files_dir.exists():
        print(json.dumps({"hash": "sha256-empty"}))
        return 0
    h = hashlib.sha256()
    for rel in _walk_files(files_dir):
        full = files_dir / rel
        content = _sha256_file(full)
        h.update(rel.encode("utf-8") + b"\0" + content.encode("ascii") + b"\n")
    print(json.dumps({"hash": "sha256-" + h.hexdigest()}))
    return 0
