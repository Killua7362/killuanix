"""den-helper: heavy ops invoked by the den Bash CLI.

Each subcommand reads JSON args on argv or stdin and writes JSON to stdout.
Commands: walk, manifest-hash, status, append-jsonl, read-jsonl, conflict-bucket,
parse-toml, write-toml.
"""
import argparse
import sys

from cmd.walk import cmd_walk
from cmd.manifest_hash import cmd_manifest_hash
from cmd.status import cmd_status, cmd_render_status
from cmd.jsonl import cmd_append_jsonl, cmd_read_jsonl
from cmd.toml import cmd_parse_toml, cmd_write_toml


def main():
    p = argparse.ArgumentParser(prog="den-helper")
    sub = p.add_subparsers(dest="cmd", required=True)

    sp = sub.add_parser("walk")
    sp.add_argument("--root", required=True)
    sp.set_defaults(func=cmd_walk)

    sp = sub.add_parser("manifest-hash")
    sp.add_argument("--root", required=True)
    sp.set_defaults(func=cmd_manifest_hash)

    sp = sub.add_parser("status")
    sp.add_argument("--cwd", required=True)
    sp.add_argument("--project-dir", required=True)
    sp.set_defaults(func=cmd_status)

    sp = sub.add_parser("render-status")
    sp.set_defaults(func=cmd_render_status)

    sp = sub.add_parser("append-jsonl")
    sp.add_argument("--path", required=True)
    sp.add_argument("--entry", default=None)
    sp.set_defaults(func=cmd_append_jsonl)

    sp = sub.add_parser("read-jsonl")
    sp.add_argument("--path", required=True)
    sp.add_argument("--tail", type=int, default=None)
    sp.set_defaults(func=cmd_read_jsonl)

    sp = sub.add_parser("parse-toml")
    sp.add_argument("--path", required=True)
    sp.set_defaults(func=cmd_parse_toml)

    sp = sub.add_parser("write-toml")
    sp.add_argument("--path", required=True)
    sp.set_defaults(func=cmd_write_toml)

    args = p.parse_args()
    sys.exit(args.func(args))


if __name__ == "__main__":
    main()
