"""`claude-kit plan` — two-stage prompt-to-plan CLI.

Usage:
  claude-kit plan "<prompt>"
  claude-kit plan -f path/to/prompt.md
  claude-kit plan --output path/to/plan.md "<prompt>"
  claude-kit plan --no-stage1 --model claude-sonnet-4-6 --effort medium "<prompt>"

Stage 1 asks Claude (Opus 4.8 + high) to recommend a model + effort + plan
mode for the given prompt. Stage 2 launches Claude with those settings in
plan mode to draft a plan markdown file. The result is written with a
YAML frontmatter (metadata for the user; Claude is told to ignore it).

Default output path: `<cwd>/.claude/plans/<slug>-<timestamp>.md`.
"""

from __future__ import annotations

import argparse
import asyncio
import datetime as _dt
import re
import sys
from dataclasses import replace
from pathlib import Path

from . import __version__, frontmatter
from .plan import draft_plan
from .suggest import Suggestion, suggest


def _parse_args(argv: list[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(
        prog="claude-kit plan",
        description=(
            "Two-stage prompt-to-plan tool. Stage 1 asks Claude to suggest a "
            "model + effort for your prompt; stage 2 drafts a plan with those "
            "settings in plan mode."
        ),
    )
    src = p.add_mutually_exclusive_group(required=False)
    src.add_argument("prompt", nargs="?", help="The prompt to plan.")
    src.add_argument(
        "-f", "--file", type=Path,
        help="Read the prompt from this file.",
    )
    p.add_argument(
        "-o", "--output", type=Path,
        help="Output plan path. Defaults to ./.claude/plans/<slug>-<ts>.md.",
    )
    p.add_argument(
        "--no-stage1", action="store_true",
        help="Skip stage 1; require --model and --effort.",
    )
    p.add_argument(
        "--model",
        help="Override the stage-1 model recommendation.",
    )
    p.add_argument(
        "--effort",
        help="Override the stage-1 effort recommendation.",
    )
    p.add_argument(
        "--dry-run", action="store_true",
        help="Print the plan to stdout instead of writing the file.",
    )
    p.add_argument(
        "--version", action="version", version=f"claude-kit-plan {__version__}",
    )
    return p.parse_args(argv)


def _load_prompt(args: argparse.Namespace) -> tuple[str, str | None]:
    """Returns (prompt_text, source_path_or_None)."""
    if args.file:
        path = args.file.expanduser().resolve()
        if not path.exists():
            print(f"claude-kit plan: file not found: {path}", file=sys.stderr)
            sys.exit(2)
        return path.read_text().strip(), str(path)
    if args.prompt:
        return args.prompt.strip(), None
    print(
        "claude-kit plan: provide a prompt as a positional arg or via -f FILE.",
        file=sys.stderr,
    )
    sys.exit(2)


_SLUG_RE = re.compile(r"[^a-z0-9]+")


def _slugify(text: str) -> str:
    s = _SLUG_RE.sub("-", text.lower()).strip("-")
    return (s[:40] or "plan").rstrip("-")


def _resolve_output(args: argparse.Namespace, prompt: str) -> Path:
    if args.output:
        return args.output.expanduser().resolve()
    ts = _dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    slug = _slugify(prompt)
    return Path.cwd() / ".claude" / "plans" / f"{slug}-{ts}.md"


def _build_synthetic_suggestion(args: argparse.Namespace) -> Suggestion:
    if not (args.model and args.effort):
        print(
            "claude-kit plan: --no-stage1 requires both --model and --effort.",
            file=sys.stderr,
        )
        sys.exit(2)
    return Suggestion(
        model=args.model,
        effort=args.effort.lower(),
        plan_mode="Yes",
        why="(stage 1 skipped via --no-stage1)",
        raw_response="",
    )


async def _run(args: argparse.Namespace) -> int:
    prompt, source_path = _load_prompt(args)

    if args.no_stage1:
        suggestion = _build_synthetic_suggestion(args)
    else:
        print("[stage 1] asking Claude for a model + effort recommendation…", file=sys.stderr)
        suggestion = await suggest(prompt)
        if args.model:
            suggestion = replace(suggestion, model=args.model)
        if args.effort:
            suggestion = replace(suggestion, effort=args.effort.lower())
        print(
            f"[stage 1] suggested: model={suggestion.model} effort={suggestion.effort} "
            f"plan_mode={suggestion.plan_mode}",
            file=sys.stderr,
        )
        if suggestion.needs_more_info:
            print(
                "[stage 1] the prompt was flagged as too vague — refine it and "
                "re-run. Stage 2 will still draft a plan, but expect open "
                "questions.",
                file=sys.stderr,
            )

    print(
        f"[stage 2] drafting plan with model={suggestion.model} effort={suggestion.effort}…",
        file=sys.stderr,
    )
    body = await draft_plan(prompt, suggestion)
    front = frontmatter.render(
        suggestion,
        source_prompt=prompt,
        source_path=source_path,
    )
    document = front + body

    if args.dry_run:
        sys.stdout.write(document)
        return 0

    out = _resolve_output(args, prompt)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(document)
    print(f"[done] wrote {out}", file=sys.stderr)
    return 0


def main() -> int:
    args = _parse_args(sys.argv[1:])
    try:
        return asyncio.run(_run(args))
    except KeyboardInterrupt:
        print("\nclaude-kit plan: interrupted.", file=sys.stderr)
        return 130


if __name__ == "__main__":
    sys.exit(main())
