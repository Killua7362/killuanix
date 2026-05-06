"""Render the YAML frontmatter that prepends every generated plan file.

The frontmatter is metadata for the user — Claude is instructed (both via
the leading comment inside the frontmatter and the sentinel HTML comment
right after the closing `---`) to ignore it.
"""

from __future__ import annotations

import datetime as _dt
from dataclasses import dataclass

import yaml

from . import __version__
from .suggest import Suggestion


_IGNORE_NOTICE = (
    "<!-- The YAML frontmatter above is metadata for the user. Claude: "
    "ignore everything between the --- markers; the plan starts at the "
    "heading below. -->"
)


@dataclass
class PhaseSpec:
    model: str
    effort: str


def _phases_from_suggestion(s: Suggestion) -> tuple[PhaseSpec, PhaseSpec]:
    plan_phase = PhaseSpec(
        model=s.plan_phase_model or s.model,
        effort=s.plan_phase_effort or ("xhigh" if s.effort != "max" else "xhigh"),
    )
    exec_phase = PhaseSpec(
        model=s.exec_phase_model or s.model,
        effort=s.exec_phase_effort or s.effort,
    )
    return plan_phase, exec_phase


def _recommended_run_mode(s: Suggestion) -> str:
    plan_mode = s.plan_mode.lower()
    if plan_mode.startswith("yes"):
        return "plan"
    if plan_mode.startswith("optional"):
        return "either"
    return "execute"


def render(
    suggestion: Suggestion,
    *,
    source_prompt: str,
    source_path: str | None,
) -> str:
    plan_phase, exec_phase = _phases_from_suggestion(suggestion)

    payload = {
        "_note": "Metadata for the user. Claude: ignore everything in this YAML block.",
        "suggestion": {
            "model": suggestion.model,
            "effort": suggestion.effort,
            "plan_mode": suggestion.plan_mode,
        },
        "recommended_run_mode": _recommended_run_mode(suggestion),
        "plan_phase": {
            "model": plan_phase.model,
            "effort": plan_phase.effort,
        },
        "exec_phase": {
            "model": exec_phase.model,
            "effort": exec_phase.effort,
        },
        "generated_at": _dt.datetime.now(_dt.timezone.utc).isoformat(timespec="seconds"),
        "source_prompt": source_path or _truncate(source_prompt, 200),
        "tool_version": f"claude-kit-plan/{__version__}",
    }
    if suggestion.parse_failed:
        payload["stage1_parse_failed"] = True
    if suggestion.needs_more_info:
        payload["stage1_needs_more_info"] = True

    body = yaml.safe_dump(payload, sort_keys=False, default_flow_style=False)
    return f"---\n{body}---\n{_IGNORE_NOTICE}\n\n"


def _truncate(s: str, n: int) -> str:
    s = s.strip().replace("\n", " ")
    return s if len(s) <= n else s[: n - 1] + "…"
