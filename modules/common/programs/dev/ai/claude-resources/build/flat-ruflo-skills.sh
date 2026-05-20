#!/usr/bin/env bash
# Flatten ruflo .claude/skills/*/ into $out, one subdir per skill, preserving
# SKILL.md and any referenced assets. Per-source catalog: no `ruflo--` prefix.
#
# Inputs:
#   RUFLO  — store path of inputs.ruflo
#   out    — runCommand output dir
set -euo pipefail

mkdir -p "$out"

if [ -d "$RUFLO/.claude/skills" ]; then
  for d in "$RUFLO"/.claude/skills/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    cp -rL --no-preserve=mode,ownership "$d" "$out/${name}"
  done
fi
