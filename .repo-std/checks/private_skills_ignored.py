#!/usr/bin/env python3
"""Skills are private by default and published only by an allowlist.

This repository is public. .gitignore ignores every skill source directory and
re-includes the published ones with `!<dir>/`, so a new internal skill stays out
of `git add -A` without anyone remembering to list it, and no internal skill
name appears in the public tree.

Two states break that contract:
- an untracked skill directory that is not ignored: `git add -A` publishes it;
- a tracked skill directory that is ignored: files added to it later are
  silently left out of the next commit.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from _dotbot import report, repo_root  # noqa: E402

SOURCES = ("skills", "claude/skills", "codex/skills", "pi/skills", "omp/skills")
PROBE = "SKILL.md"


def git(root: Path, *args: str, stdin: str | None = None) -> list[str]:
    out = subprocess.run(["git", *args], cwd=root, input=stdin, capture_output=True, text=True, check=False)
    return [line for line in out.stdout.splitlines() if line]


def main() -> int:
    root = repo_root(sys.argv[1:])
    if not (root / ".git").exists():
        print("SKIP  not a git checkout")
        return 0

    tracked_dirs = {name.rsplit("/", 1)[0] for name in git(root, "ls-files", *SOURCES)}
    entries = [
        entry.relative_to(root).as_posix()
        for source in SOURCES
        if (root / source).is_dir()
        for entry in sorted((root / source).iterdir())
        if entry.is_dir()
    ]
    probes = "\n".join(f"{rel}/{PROBE}" for rel in entries)
    ignored = {p.rsplit("/", 1)[0] for p in git(root, "check-ignore", "--no-index", "--stdin", stdin=probes)}

    violations = []
    for rel in entries:
        tracked = any(d == rel or d.startswith(rel + "/") for d in tracked_dirs)
        if tracked and rel in ignored:
            violations.append(f"{rel}: tracked but ignored — add `!{rel}/` to .gitignore")
        elif not tracked and rel not in ignored:
            violations.append(
                f"{rel}: untracked and not ignored — `git add -A` would publish it. "
                f"Commit it on purpose, or drop its `!{rel}/` line from .gitignore."
            )

    return report(violations, f"{len(entries)} skill dirs: published ones allowlisted, the rest ignored")


if __name__ == "__main__":
    raise SystemExit(main())
