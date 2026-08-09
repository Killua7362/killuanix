"""`.denhidden` → per-repo `info/exclude` planning + `.denignore` matching.

`.denhidden` is a gitignore-syntax file whose patterns are interpreted
relative to the binding root. Because a nested clone is a *separate* git
scope (a parent repo's ignore rules don't reach inside a nested repo), each
pattern must be routed to the repo it actually applies to and re-anchored to
that repo's frame. `hidden-plan` emits `{repo: [lines...]}` where repo is "."
for the binding-root repo or a registered clone path; the Bash side writes
each list into that repo's `.git/info/exclude` as a managed block, making
`.denhidden` the single source of truth (stale lines are dropped on rewrite).
"""
import json
from pathlib import Path

from lib.ignore import load_ignore_spec


def _load_lines(path) -> list:
    p = Path(path)
    if not p.exists():
        return []
    out = []
    for ln in p.read_text().splitlines():
        s = ln.strip()
        if not s or s.startswith("#"):
            continue
        out.append(s)
    return out


def _clone_paths(clones_json) -> list:
    p = Path(clones_json)
    if not p.exists():
        return []
    try:
        data = json.loads(p.read_text())
    except Exception:
        return []
    return [c.get("path", "") for c in data.get("clones", []) if c.get("path")]


def _concrete_prefix(body: str) -> str:
    """Leading directory components of `body` up to the first wildcard.

    Used to find which clone a pattern is anchored into. Only dir components
    *before* the final path segment count (the final segment may itself be a
    glob like `*.log`).
    """
    parts = body.split("/")
    concrete = []
    for part in parts[:-1]:
        if any(ch in part for ch in "*?["):
            break
        concrete.append(part)
    return "/".join(concrete)


def _map_pattern(pattern: str, clone_paths: list):
    """Map a root-relative gitignore pattern to (repo, repo_relative_line).

    A pattern anchored under a registered clone path is stripped of that
    prefix and re-anchored (leading `/`) inside the clone. Everything else
    lands in the root repo ("."), preserving its original anchoring so
    unanchored patterns (`*.log`, `build/`) keep gitignore's match-anywhere
    semantics. `!` negation is carried through.
    """
    neg = pattern.startswith("!")
    body = pattern[1:] if neg else pattern
    anchored = body.startswith("/")
    body2 = body[1:] if anchored else body

    prefix = _concrete_prefix(body2)
    best = ""
    for c in clone_paths:
        if c == ".":
            continue
        if prefix == c or prefix.startswith(c + "/"):
            if len(c) > len(best):
                best = c

    if best:
        remainder = body2[len(best) + 1:]
        return best, ("!" if neg else "") + "/" + remainder
    return ".", ("!" if neg else "") + ("/" if anchored else "") + body2


def cmd_hidden_plan(args):
    lines = _load_lines(args.denhidden)
    clones = _clone_paths(args.clones)
    plan = {}
    for pat in lines:
        repo, line = _map_pattern(pat, clones)
        plan.setdefault(repo, []).append(line)
    print(json.dumps(plan))
    return 0


def cmd_ignore_match(args):
    """Exit 0 if <rel> matches <project-dir>/.denignore, 1 otherwise."""
    spec = load_ignore_spec(args.project_dir)
    return 0 if spec.match_file(args.rel) else 1
