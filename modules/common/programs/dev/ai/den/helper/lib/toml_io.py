"""Minimal TOML serializer + tomllib re-export for den-helper."""
import io
import json

try:
    import tomllib  # py311+
except ImportError:  # pragma: no cover
    import tomli as tomllib  # type: ignore


def _toml_dump(data: dict) -> str:
    # Minimal TOML serializer — emits flat tables, scalar arrays, and
    # arrays-of-tables (`[[entry]]`) for .den-project.toml, meta.toml,
    # and manifest.toml.
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

    def is_array_of_tables(v):
        return isinstance(v, list) and len(v) > 0 and all(isinstance(x, dict) for x in v)

    out = io.StringIO()
    # Top-level scalars and scalar arrays first.
    for k, v in data.items():
        if isinstance(v, dict) or is_array_of_tables(v):
            continue
        out.write(f"{k} = {fmt_val(v)}\n")
    # Then [tables].
    for k, v in data.items():
        if isinstance(v, dict):
            out.write(f"\n[{k}]\n")
            for kk, vv in v.items():
                out.write(f"{kk} = {fmt_val(vv)}\n")
    # Then [[arrays of tables]].
    for k, v in data.items():
        if is_array_of_tables(v):
            for table in v:
                out.write(f"\n[[{k}]]\n")
                for kk, vv in table.items():
                    out.write(f"{kk} = {fmt_val(vv)}\n")
    return out.getvalue()
