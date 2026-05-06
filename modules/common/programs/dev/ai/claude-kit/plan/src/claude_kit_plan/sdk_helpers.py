"""Thin wrappers around `claude_agent_sdk.query` so suggest.py / plan.py can
run a one-shot conversation and recover the assistant's text + metadata.

The SDK exposes `effort` as `Literal["low","medium","high","max"]`. The
suggestion skill also produces `xhigh` (which the underlying claude CLI
accepts but the SDK's type narrowing rejects). Callers route `xhigh`
through `extra_args={"--effort": "xhigh"}` instead — see `_build_options`.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

from claude_agent_sdk import ClaudeAgentOptions, query  # type: ignore[import-not-found]


KNOWN_SDK_EFFORTS = {"low", "medium", "high", "max"}


@dataclass
class CallResult:
    text: str
    cost_usd: float | None = None
    duration_ms: int | None = None
    session_id: str | None = None
    raw_messages: list[Any] = field(default_factory=list)


def _build_options(
    *,
    model: str,
    effort: str,
    system_prompt: str,
    permission_mode: str = "default",
) -> ClaudeAgentOptions:
    kwargs: dict[str, Any] = {
        "model": model,
        "system_prompt": system_prompt,
        "permission_mode": permission_mode,
        "setting_sources": [],
    }
    if effort in KNOWN_SDK_EFFORTS:
        kwargs["effort"] = effort
    else:
        # xhigh (or any future tier) — pass through to the CLI directly.
        kwargs["extra_args"] = {"--effort": effort}
    return ClaudeAgentOptions(**kwargs)


async def run_query(
    *,
    prompt: str,
    model: str,
    effort: str,
    system_prompt: str,
    permission_mode: str = "default",
) -> CallResult:
    options = _build_options(
        model=model,
        effort=effort,
        system_prompt=system_prompt,
        permission_mode=permission_mode,
    )

    text_parts: list[str] = []
    result = CallResult(text="")

    async for message in query(prompt=prompt, options=options):
        result.raw_messages.append(message)
        # AssistantMessage carries .content with TextBlock entries.
        content = getattr(message, "content", None)
        if content:
            for block in content:
                t = getattr(block, "text", None)
                if t:
                    text_parts.append(t)
        # ResultMessage carries cost / duration / session_id.
        if hasattr(message, "total_cost_usd"):
            result.cost_usd = getattr(message, "total_cost_usd", None)
            result.duration_ms = getattr(message, "duration_ms", None)
            result.session_id = getattr(message, "session_id", None)

    result.text = "".join(text_parts)
    return result
