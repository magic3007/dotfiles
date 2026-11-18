#!/usr/bin/env python3
"""Repository paths named by the top-level docs must exist.

A directory that is renamed or dropped leaves the docs pointing at nothing, and
prose decays without failing anything. Scope is the three documents a reader
starts from; skills and vendored trees describe foreign repositories and are out
of scope.

Only paths that look like repository paths are checked: a backticked token with
a slash or a known top-level name, not every word in a code span.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from _dotbot import report, repo_root  # noqa: E402

DOCS = ("README.md", "AGENTS.md", "docs/REPO_GUIDE.md")

CODE_SPAN = re.compile(r"`([^`\n]+)`")
# A repo path: no leading ~ or /, no URL, no shell, and it has a slash or a dot.
CANDIDATE = re.compile(r"^[A-Za-z0-9_.-]+(/[A-Za-z0-9_.*-]+)*/?$")


def is_candidate(token: str, root: Path) -> bool:
    if token.startswith(("~", "/", "$", "-", "http")) or " " in token:
        return False
    if not CANDIDATE.match(token):
        return False
    head = token.split("/", 1)[0]
    return (root / head).exists() or head in {"docs", ".repo-std", ".github"}


def main() -> int:
    root = repo_root(sys.argv[1:])
    violations = []
    checked = 0

    for doc in DOCS:
        path = root / doc
        if not path.is_file():
            continue
        for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            for token in CODE_SPAN.findall(line):
                token = token.strip()
                if not is_candidate(token, root):
                    continue
                checked += 1
                target = root / token.rstrip("/")
                if "*" in token:
                    if not list(root.glob(token)):
                        violations.append(f"{doc}:{lineno}: `{token}` matches nothing")
                elif not target.exists():
                    violations.append(f"{doc}:{lineno}: `{token}` does not exist")

    return report(violations, f"{checked} repository paths named by the docs exist")


if __name__ == "__main__":
    raise SystemExit(main())
