"""`append-jsonl` and `read-jsonl` subcommands."""
import datetime
import json
import sys
from pathlib import Path


def cmd_append_jsonl(args):
    path = Path(args.path)
    path.parent.mkdir(parents=True, exist_ok=True)
    entry = json.loads(args.entry) if args.entry else json.loads(sys.stdin.read())
    if "ts" not in entry:
        entry["ts"] = datetime.datetime.now().astimezone().isoformat()
    with path.open("a") as f:
        f.write(json.dumps(entry) + "\n")
    return 0


def cmd_read_jsonl(args):
    path = Path(args.path)
    if not path.exists():
        print(json.dumps([]))
        return 0
    out = []
    for ln in path.read_text().splitlines():
        ln = ln.strip()
        if not ln:
            continue
        try:
            out.append(json.loads(ln))
        except json.JSONDecodeError:
            continue
    if args.tail:
        out = out[-args.tail:]
    print(json.dumps(out))
    return 0
