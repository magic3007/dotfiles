#!/usr/bin/env python3
"""Every SKILL.md must declare what the loaders read.

omp's native provider skips a skill whose frontmatter has no `description`, and
scripts/sync-skills.py keys the generated views on `name`. Both failures are
silent: the skill simply never appears.

Directory name and frontmatter name may differ on purpose — sync-skills.py names
each view entry after the frontmatter, which is how `skills/canvo` is exported as
`canvo-op`. What must never happen is a missing or empty field.

Bundles (a directory of skills, with or without a SKILL.md of its own) are walked
too, so a nested skill cannot hide a missing description.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import yaml  # noqa: E402

from _dotbot import report, repo_root  # noqa: E402

# Skill source trees, in the layout scripts/sync-skills.py reads.
SOURCES = ("skills", "claude/skills", "codex/skills", "pi/skills", "omp/skills")

# Upstream bundles: they ship their own quality bar and we only consume them.
VENDORED = {"skills/scientific-agent-skills"}

MAX_DEPTH = 3


def frontmatter(path: Path) -> dict | None:
    text = path.read_text(encoding="utf-8", errors="replace")
    if not text.startswith("---"):
        return None
    end = text.find("\n---", 3)
    if end == -1:
        return None
    try:
        data = yaml.safe_load(text[3:end])
    except yaml.YAMLError:
        return None
    return data if isinstance(data, dict) else None


def main() -> int:
    root = repo_root(sys.argv[1:])
    violations = []
    checked = 0

    for source in SOURCES:
        base = root / source
        if not base.is_dir():
            continue
        for skill_md in sorted(base.rglob("SKILL.md")):
            rel = skill_md.relative_to(root)
            if len(rel.relative_to(source).parts) > MAX_DEPTH:
                continue
            if any(str(rel).startswith(v + "/") for v in VENDORED):
                continue
            checked += 1
            meta = frontmatter(skill_md)
            if meta is None:
                violations.append(f"{rel}: no parsable YAML frontmatter")
                continue
            if not str(meta.get("name", "")).strip():
                violations.append(f"{rel}: frontmatter has no `name`; the generated view has nothing to call it")
            if not str(meta.get("description", "")).strip():
                violations.append(f"{rel}: frontmatter has no `description`; omp skips such a skill silently")

    return report(violations, f"{checked} SKILL.md files declare name and description")


if __name__ == "__main__":
    raise SystemExit(main())
