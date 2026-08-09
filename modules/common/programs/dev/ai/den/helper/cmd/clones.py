"""`clone-plan` — reconcile a disk scan of git repos against clones.json.

Bash scans the binding root for git work trees and pipes a JSON array of
`{path, remote}` on stdin; this emits a plan the `den clone sync|drift`
commands render/apply. Invariant on clones.json: paths are unique, remotes may
repeat (same remote at several paths is allowed; the same path twice is not).
"""
import json
import sys
from pathlib import Path


def _load_clones(path) -> list:
    p = Path(path)
    if not p.exists():
        return []
    try:
        return json.load(open(p)).get("clones", []) or []
    except Exception:
        return []


def cmd_clone_plan(args):
    existing = _load_clones(args.clones)
    scanned = json.load(sys.stdin)

    ex_by_path = {}
    for e in existing:
        p = e.get("path")
        if p is not None:
            ex_by_path[p] = e.get("remote", "") or ""
    sc_by_path = {s["path"]: (s.get("remote", "") or "") for s in scanned}

    add = []          # scanned repo, path not yet in clones.json → append
    conflicts = []    # path in both, remotes differ
    no_remote = []    # scanned repo with no origin, or clones.json entry w/ no remote but present
    unchanged = []    # path in both, same remote

    for s in scanned:
        p = s["path"]
        r = s.get("remote", "") or ""
        if r == "":
            no_remote.append(p)          # present repo has no origin → can't record
            continue
        if p in ex_by_path:
            er = ex_by_path[p]
            if er == "":
                no_remote.append(p)      # clones.json entry lacks a remote → fix it
            elif er == r:
                unchanged.append(p)
            else:
                conflicts.append({"path": p, "existing": er, "found": r})
        else:
            add.append({"path": p, "remote": r})

    # drift-only views
    missing = [e.get("path") for e in existing
               if e.get("path") not in sc_by_path and e.get("path") != "."]
    untracked = [s["path"] for s in scanned if s["path"] not in ex_by_path]

    print(json.dumps({
        "add": add,
        "conflicts": conflicts,
        "noRemote": no_remote,
        "unchanged": unchanged,
        "missing": missing,
        "untracked": untracked,
    }))
    return 0
