#!/usr/bin/env python3
"""Untracked skills must be ignored on purpose, not by accident.

This repository is public, and internal skills are kept local by listing them in
.gitignore. A new internal skill is untracked either way, so "it does not show up
in git status" proves nothing: one `git add -A` publishes it. The check demands
an explicit .gitignore entry for every untracked skill directory, which turns
"remember not to commit it" into a state git itself enforces.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from _dotbot import report, repo_root  # noqa: E402

SOURCES = ("skills", "claude/skills", "codex/skills", "pi/skills", "omp/skills")


def git(root: Path, *args: str) -> list[str]:
    out = subprocess.run(["git", *args], cwd=root, capture_output=True, text=True, check=False)
    return [line for line in out.stdout.splitlines() if line]


def main() -> int:
    root = repo_root(sys.argv[1:])
    if not (root / ".git").exists():
        print("SKIP  not a git checkout")
        return 0

    tracked = set(git(root, "ls-files"))
    ignored = set(git(root, "ls-files", "--others", "--ignored", "--exclude-standard", "--directory"))
    ignored_dirs = {entry.rstrip("/") for entry in ignored}

    violations = []
    checked = 0
    for source in SOURCES:
        base = root / source
        if not base.is_dir():
            continue
        for skill_dir in sorted(p for p in base.iterdir() if p.is_dir()):
            rel = skill_dir.relative_to(root).as_posix()
            if any(name.startswith(rel + "/") for name in tracked):
                continue
            checked += 1
            if rel not in ignored_dirs:
                violations.append(
                    f"{rel}: untracked and not ignored — `git add -A` would publish it. "
                    f"Add it to .gitignore, or commit it on purpose."
                )

    return report(violations, f"{checked} untracked skill dirs are explicitly ignored")


if __name__ == "__main__":
    raise SystemExit(main())
