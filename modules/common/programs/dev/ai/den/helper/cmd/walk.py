"""`walk` subcommand."""
import json
from pathlib import Path

from lib.manifest import _walk_files


def cmd_walk(args):
    root = Path(args.root).resolve()
    if not root.exists():
        print(json.dumps({"files": []}))
        return 0
    files = _walk_files(root)
    print(json.dumps({"files": files}))
    return 0
