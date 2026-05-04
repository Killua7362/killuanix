"""File-tree walk + content hashing helpers."""
import hashlib
import os
from pathlib import Path


def _walk_files(root: Path) -> list[str]:
    out = []
    for dirpath, dirnames, filenames in os.walk(root):
        # skip dotfiles directories at the root level conservatively? No —
        # users may legitimately ship .claude/ etc. We walk everything.
        dirnames.sort()
        for fn in sorted(filenames):
            full = Path(dirpath) / fn
            rel = str(full.relative_to(root))
            out.append(rel)
    return out


def _sha256_file(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()
