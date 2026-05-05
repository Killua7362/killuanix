"""`status` and `render-status` subcommands."""
import json
import os
import sys
from pathlib import Path

from lib.ignore import _matches_ignore, _read_denignore
from lib.manifest import _walk_files
from lib.toml_io import tomllib


def _load_manifest_kinds(project_dir: Path) -> dict:
    """Return {rel: kind} from <project_dir>/manifest.toml.

    Default kind for any rel not in the map is "symlink". Tolerates a
    missing or malformed manifest.
    """
    manifest = project_dir / "manifest.toml"
    if not manifest.exists():
        return {}
    try:
        with manifest.open("rb") as f:
            data = tomllib.load(f)
    except Exception:
        return {}
    out = {}
    for entry in data.get("entry", []) or []:
        src = entry.get("src", "")
        kind = entry.get("kind")
        if not src.startswith("files/") or not kind:
            continue
        out[src[len("files/"):]] = kind
    return out


def cmd_status(args):
    """Compute drift buckets between project files/ and the bound cwd.

    Buckets:
      missing-link             : project has the file, cwd has nothing
      wrong-target             : link is the wrong kind / points elsewhere
      replaced-with-real-file  : cwd has a real file where a link should be
                                 (or a hardlink whose inode no longer matches)
      unmanaged-real-file      : cwd has a real file at a path the manifest expects to be linked
      untracked                : real file in cwd, not symlinked, not in host_only, not ignored

    For entries with kind=hardlink in manifest.toml, "ok" requires the
    cwd file to be a real file with the same inode as the project copy.
    A different inode (e.g. after an editor's atomic save) shows up as
    replaced-with-real-file — `den re-add <path>` rebuilds the hardlink.
    """
    cwd = Path(args.cwd).resolve()
    project_dir = Path(args.project_dir).resolve()
    meta_file = cwd / ".den-meta.json"
    meta = json.loads(meta_file.read_text()) if meta_file.exists() else {"symlinks": [], "host_only": []}
    host_only = set(meta.get("host_only", []))
    symlinks_index = {s["target"]: s for s in meta.get("symlinks", [])}
    ignore_patterns = _read_denignore(project_dir)
    kinds = _load_manifest_kinds(project_dir)

    files_dir = project_dir / "files"
    project_files = _walk_files(files_dir) if files_dir.exists() else []

    missing_link = []
    wrong_target = []
    replaced_with_real_file = []
    unmanaged_real_file = []
    ok = []

    for rel in project_files:
        if _matches_ignore(rel, ignore_patterns):
            continue
        target = cwd / rel
        expected_src = files_dir / rel
        kind = kinds.get(rel, "symlink")

        if kind == "hardlink":
            # cwd should be a real file (no symlink) with the same inode
            # as the project copy. A symlink here is "wrong-target"; a
            # mismatched inode is "replaced-with-real-file".
            if not target.exists() and not target.is_symlink():
                missing_link.append(rel)
                continue
            if target.is_symlink():
                actual = os.readlink(str(target))
                wrong_target.append({"path": rel, "actual": actual,
                                     "expected": f"hardlink ↔ {expected_src}"})
                continue
            try:
                cwd_ino = target.stat().st_ino
                src_ino = expected_src.stat().st_ino
            except OSError:
                missing_link.append(rel)
                continue
            if cwd_ino == src_ino:
                ok.append(rel)
            else:
                replaced_with_real_file.append(rel)
            continue

        # Default: symlink kind
        if not target.exists() and not target.is_symlink():
            missing_link.append(rel)
            continue
        if target.is_symlink():
            actual = os.readlink(str(target))
            if Path(actual).resolve() == expected_src.resolve():
                ok.append(rel)
            else:
                wrong_target.append({"path": rel, "actual": actual, "expected": str(expected_src)})
        else:
            # real file
            if rel in symlinks_index:
                replaced_with_real_file.append(rel)
            else:
                unmanaged_real_file.append(rel)

    # untracked: real files in cwd that aren't in project, not host_only,
    # not ignore-matched, not .den-meta.json itself.
    untracked = []
    for dirpath, dirnames, filenames in os.walk(cwd):
        # don't recurse into .den-staging/ or .den-generations/
        dirnames[:] = [d for d in dirnames if d not in (".den-staging", ".den-generations", ".git")]
        for fn in filenames:
            full = Path(dirpath) / fn
            if full.is_symlink():
                continue
            rel = str(full.relative_to(cwd))
            if rel.startswith(".den-meta.json"):
                continue
            if rel in host_only:
                continue
            if rel in {f for f in project_files}:
                continue
            if _matches_ignore(rel, ignore_patterns):
                continue
            untracked.append(rel)

    result = {
        "ok": ok,
        "missing-link": missing_link,
        "wrong-target": wrong_target,
        "replaced-with-real-file": replaced_with_real_file,
        "unmanaged-real-file": unmanaged_real_file,
        "untracked": untracked,
    }
    result["drift_count"] = (
        len(missing_link)
        + len(wrong_target)
        + len(replaced_with_real_file)
        + len(unmanaged_real_file)
    )
    print(json.dumps(result))
    return 0


def cmd_render_status(args):
    """Pretty-print the status JSON from cmd_status."""
    data = json.loads(sys.stdin.read())
    from_color = sys.stdout.isatty() and os.environ.get("NO_COLOR") is None
    def c(code, s):
        return f"\033[{code}m{s}\033[0m" if from_color else s

    any_drift = data.get("drift_count", 0) > 0
    if any_drift:
        print(c("1;33", f"den status — {data['drift_count']} drift item(s):"))
    else:
        print(c("1;32", "den status — clean"))

    if data["missing-link"]:
        print(c("31", "  missing-link:") + "    (project has it, cwd does not — run `den pull`)")
        for p in data["missing-link"]:
            print(f"    - {p}")
    if data["wrong-target"]:
        print(c("31", "  wrong-target:") + "    (link is wrong kind or points elsewhere)")
        for e in data["wrong-target"]:
            print(f"    - {e['path']} -> {e['actual']} (expected {e['expected']})")
    if data["replaced-with-real-file"]:
        print(c("33", "  replaced-with-real-file:") + " (editor atomic-save? — run `den re-add <path>`)")
        for p in data["replaced-with-real-file"]:
            print(f"    - {p}")
    if data["unmanaged-real-file"]:
        print(c("33", "  unmanaged-real-file:") + " (manifest expects link, cwd has real file)")
        for p in data["unmanaged-real-file"]:
            print(f"    - {p}")
    if data["untracked"]:
        print(c("36", "  untracked:") + " (real files in cwd; run `den add <path>` or `den ignore <path>`)")
        for p in data["untracked"]:
            print(f"    - {p}")
    return 0 if not any_drift else 1
