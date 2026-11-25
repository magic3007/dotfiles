#!/usr/bin/env python3
"""Vendor installers must not leave PATH lines in the tracked rc files.

~/.bashrc, ~/.zshrc and ~/.profile are symlinks into this repository, so an
installer that appends to them edits the repository itself. Observed with the
Antigravity CLI installer (2026-11-16): four rc files gained a PATH line, three
of them tracked here.

Only installer signatures are matched. A hand-maintained block that looks
similar (the conda block in shell/bash/bashrc) is deliberately not flagged: a
rule that cannot tell the two apart produces noise, and a noisy gate gets
ignored.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from _lib import report, repo_root  # noqa: E402

RC_FILES = ("shell/bash/bashrc", "shell/zsh/zshrc", "shell/zsh/zshenv", "shell/common.sh")

MARKERS = (
    re.compile(r"#\s*Added by ", re.I),
    re.compile(r"#\s*Generated for envman", re.I),
    re.compile(r"^#\s*bun(\s+completions)?\s*$"),
)

def main() -> int:
    root = repo_root(sys.argv[1:])
    violations = []
    checked = 0

    for rc in RC_FILES:
        path = root / rc
        if not path.is_file():
            continue
        checked += 1
        for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            for marker in MARKERS:
                if marker.search(line):
                    violations.append(
                        f"{rc}:{lineno}: installer-appended line {line.strip()!r}; "
                        f"revert it and set PATH in the maintained runtime file instead"
                    )
                    break

    return report(violations, f"{checked} rc files carry no installer-appended lines")


if __name__ == "__main__":
    raise SystemExit(main())
