"""`parse-toml` and `write-toml` subcommands."""
import json
import sys
from pathlib import Path

from lib.toml_io import _toml_dump, tomllib


def cmd_parse_toml(args):
    path = Path(args.path)
    if not path.exists():
        print(json.dumps({}))
        return 0
    with path.open("rb") as f:
        data = tomllib.load(f)
    print(json.dumps(data))
    return 0


def cmd_write_toml(args):
    path = Path(args.path)
    path.parent.mkdir(parents=True, exist_ok=True)
    data = json.loads(sys.stdin.read())
    path.write_text(_toml_dump(data))
    return 0
