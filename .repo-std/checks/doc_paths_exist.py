#!/usr/bin/env python3
"""Repository paths named by the top-level docs must exist.

A directory that is renamed or dropped leaves the docs pointing at nothing, and
prose decays without failing anything. Scope is the three documents a reader
starts from; skills and vendored trees describe foreign repositories and are out
of scope.

Only tokens that look like repository paths are checked: a backticked token with
a slash, not every word in a code span. Existence means "would be in a clean
clone": a file that is tracked or would be added by `git add -A`. A gitignored
local directory does not count, and neither does a deleted top-level directory.
"""

from __future__ import annotations

import fnmatch
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from _lib import report, repo_root  # noqa: E402

DOCS = ("README.md", "AGENTS.md", "docs/REPO_GUIDE.md")

CODE_SPAN = re.compile(r"`([^`\n]+)`")
CANDIDATE = re.compile(r"^[A-Za-z0-9_.-]+(/[A-Za-z0-9_.*-]+)+/?$|^[A-Za-z0-9_.-]+/$")


def is_candidate(token: str) -> bool:
    return not token.startswith(("~", "/", "$", "-", "http")) and bool(CANDIDATE.match(token))


def publishable(root: Path) -> set[str] | None:
    """Files and their parent directories a clean clone would hold; None outside git."""
    out = subprocess.run(
        ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
        cwd=root,
        capture_output=True,
        text=True,
        check=False,
    )
    if out.returncode != 0 or not (root / ".git").exists():
        return None
    paths: set[str] = set()
    for name in filter(None, out.stdout.split("\0")):
        if not (root / name).exists():
            continue
        parts = name.split("/")
        paths.update("/".join(parts[:i]) for i in range(1, len(parts) + 1))
    return paths


def main() -> int:
    root = repo_root(sys.argv[1:])
    known = publishable(root)
    violations = []
    checked = 0

    def exists(token: str) -> bool:
        rel = token.removeprefix("./").rstrip("/")
        if known is None:
            return any(root.glob(rel)) if "*" in rel else (root / rel).exists()
        return any(fnmatch.fnmatchcase(p, rel) for p in known) if "*" in rel else rel in known

    for doc in DOCS:
        path = root / doc
        if not path.is_file():
            continue
        for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            for token in CODE_SPAN.findall(line):
                token = token.strip()
                if not is_candidate(token):
                    continue
                checked += 1
                if not exists(token):
                    violations.append(f"{doc}:{lineno}: `{token}` is not in a clean clone")

    return report(violations, f"{checked} repository paths named by the docs exist")


if __name__ == "__main__":
    raise SystemExit(main())
