"""Stage 1 — ask Claude (Opus 4.8 + high) for a model+effort recommendation.

Reads `prompts/suggestion.md` from package data, sends the user's original
prompt as a `/suggestion "..."` message, parses the structured reply.

If parsing fails, falls back to (claude-opus-4-8, xhigh, plan-mode Yes) and
flags the suggestion as `parse_failed`.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from importlib.resources import files

from .sdk_helpers import run_query


SUGGESTION_PROMPT = (
    files("claude_kit_plan.prompts").joinpath("suggestion.md").read_text()
)


@dataclass
class Suggestion:
    model: str
    effort: str
    plan_mode: str           # "Yes" | "No" | "Optional" | "N/A"
    why: str
    plan_phase_model: str | None = None
    plan_phase_effort: str | None = None
    exec_phase_model: str | None = None
    exec_phase_effort: str | None = None
    raw_response: str = ""
    parse_failed: bool = False
    needs_more_info: bool = False


_MODEL_RE = re.compile(r"\*\*Model:\*\*\s*(.+)")
_EFFORT_RE = re.compile(r"\*\*Effort:\*\*\s*(.+)")
_PLANMODE_RE = re.compile(r"\*\*Plan mode:\*\*\s*(.+)")
_WHY_RE = re.compile(r"\*\*Why:\*\*\s*(.+?)(?=\n\*\*|\Z)", re.DOTALL)
_PHASE_RE = re.compile(
    r"\*\*(Plan|Execution) phase:\*\*\s*([\w\-.]+)\s*\+\s*(\w+)"
)


def _parse(text: str) -> Suggestion:
    model_m = _MODEL_RE.search(text)
    effort_m = _EFFORT_RE.search(text)
    planmode_m = _PLANMODE_RE.search(text)
    why_m = _WHY_RE.search(text)

    if not (model_m and effort_m and planmode_m):
        return Suggestion(
            model="claude-opus-4-8",
            effort="xhigh",
            plan_mode="Yes",
            why="(stage 1 output unparseable; falling back to opus-4.8 + xhigh + plan)",
            raw_response=text,
            parse_failed=True,
        )

    model = model_m.group(1).strip().rstrip(".")
    effort = effort_m.group(1).strip().rstrip(".").lower()
    plan_mode = planmode_m.group(1).strip().rstrip(".")
    why = (why_m.group(1).strip() if why_m else "").strip()

    needs_more_info = (
        "need more info" in model.lower() or "need more info" in effort.lower()
    )

    plan_phase_model = plan_phase_effort = None
    exec_phase_model = exec_phase_effort = None
    for m in _PHASE_RE.finditer(text):
        phase, mdl, eff = m.group(1), m.group(2), m.group(3).lower()
        if phase == "Plan":
            plan_phase_model, plan_phase_effort = mdl, eff
        else:
            exec_phase_model, exec_phase_effort = mdl, eff

    return Suggestion(
        model=model,
        effort=effort,
        plan_mode=plan_mode,
        why=why,
        plan_phase_model=plan_phase_model,
        plan_phase_effort=plan_phase_effort,
        exec_phase_model=exec_phase_model,
        exec_phase_effort=exec_phase_effort,
        raw_response=text,
        needs_more_info=needs_more_info,
    )


async def suggest(user_prompt: str) -> Suggestion:
    """Run stage 1. Always returns a Suggestion; check .parse_failed / .needs_more_info."""
    result = await run_query(
        prompt=f'/suggestion "{user_prompt}"',
        model="claude-opus-4-8",
        effort="high",
        system_prompt=SUGGESTION_PROMPT,
        permission_mode="default",
    )
    return _parse(result.text)
