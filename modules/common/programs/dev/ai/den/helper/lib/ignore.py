"""`.denignore` parsing + matching."""
import fnmatch
import os
from pathlib import Path


def _read_denignore(project_dir: Path) -> list[str]:
    f = project_dir / ".denignore"
    if not f.exists():
        return []
    return [
        ln.strip()
        for ln in f.read_text().splitlines()
        if ln.strip() and not ln.strip().startswith("#")
    ]


def _matches_ignore(rel: str, patterns: list[str]) -> bool:
    for p in patterns:
        if fnmatch.fnmatch(rel, p) or fnmatch.fnmatch(os.path.basename(rel), p):
            return True
        # gitignore-style dir match
        if p.endswith("/") and rel.startswith(p):
            return True
    return False
