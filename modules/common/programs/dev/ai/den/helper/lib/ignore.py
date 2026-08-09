"""`.denignore` parsing + matching — full gitignore semantics via pathspec."""
from pathlib import Path

import pathspec


def load_ignore_spec(project_dir) -> pathspec.PathSpec:
    """Compile <project_dir>/.denignore into a gitwildmatch PathSpec.

    Full gitignore syntax: leading-`/` anchoring, `**`, `*` that does not
    cross `/`, `?`, `[...]` character classes, trailing-`/` dir match, and
    order-sensitive `!` negation. Blank lines and `#` comments are handled by
    pathspec. Returns an empty spec if the file is absent.
    """
    f = Path(project_dir) / ".denignore"
    if not f.exists():
        return pathspec.PathSpec.from_lines("gitwildmatch", [])
    return pathspec.PathSpec.from_lines("gitwildmatch", f.read_text().splitlines())
