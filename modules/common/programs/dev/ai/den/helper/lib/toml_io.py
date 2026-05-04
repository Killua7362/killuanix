"""Minimal TOML serializer + tomllib re-export for den-helper."""
import io
import json

try:
    import tomllib  # py311+
except ImportError:  # pragma: no cover
    import tomli as tomllib  # type: ignore


def _toml_dump(data: dict) -> str:
    # Minimal TOML serializer — we only emit flat tables and arrays of
    # strings/numbers/booleans for .den-project.toml and meta.toml.
    def fmt_val(v):
        if isinstance(v, bool):
            return "true" if v else "false"
        if isinstance(v, (int, float)):
            return str(v)
        if isinstance(v, str):
            return json.dumps(v)
        if isinstance(v, list):
            return "[" + ", ".join(fmt_val(x) for x in v) + "]"
        raise TypeError(f"unsupported toml type: {type(v)}")

    out = io.StringIO()
    # top-level scalars first
    for k, v in data.items():
        if not isinstance(v, dict):
            out.write(f"{k} = {fmt_val(v)}\n")
    # then [tables]
    for k, v in data.items():
        if isinstance(v, dict):
            out.write(f"\n[{k}]\n")
            for kk, vv in v.items():
                out.write(f"{kk} = {fmt_val(vv)}\n")
    return out.getvalue()
