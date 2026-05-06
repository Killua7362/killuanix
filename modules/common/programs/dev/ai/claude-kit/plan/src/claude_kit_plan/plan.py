"""Stage 2 — draft the plan markdown using the suggested model/effort.

Reads `prompts/plan-template.md` from package data, hands the user's
original prompt + a suggestion echo block to Claude in plan-mode, and
returns the assistant's body. The frontmatter is added by the caller
(`cli.py`) using `frontmatter.render`.
"""

from __future__ import annotations

from importlib.resources import files

from .sdk_helpers import run_query
from .suggest import Suggestion


PLAN_TEMPLATE_PROMPT = (
    files("claude_kit_plan.prompts").joinpath("plan-template.md").read_text()
)


def _build_user_message(user_prompt: str, suggestion: Suggestion) -> str:
    suggestion_block = (
        f"```\n"
        f"Stage-1 suggestion (advisory; the calling tool already encoded "
        f"this into frontmatter — do not re-emit it):\n"
        f"  model:     {suggestion.model}\n"
        f"  effort:    {suggestion.effort}\n"
        f"  plan_mode: {suggestion.plan_mode}\n"
        f"```\n"
    )
    return f"{suggestion_block}\nUser prompt:\n\n{user_prompt}\n"


async def draft_plan(user_prompt: str, suggestion: Suggestion) -> str:
    """Run stage 2. Returns the markdown body (no frontmatter)."""
    result = await run_query(
        prompt=_build_user_message(user_prompt, suggestion),
        model=suggestion.model,
        effort=suggestion.effort,
        system_prompt=PLAN_TEMPLATE_PROMPT,
        permission_mode="plan",
    )
    return result.text.strip() + "\n"
