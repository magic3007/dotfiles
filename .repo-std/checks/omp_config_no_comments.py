#!/usr/bin/env python3
"""omp/config.yml must stay comment-free and writable.

`omp config set` and `omp config reset` rewrite the file as pure YAML and strip
every comment, so a comment placed there is lost at the next toggle and the
explanation it carried disappears with it. Explanatory prose belongs in
omp/README.md. models.yml and WATCHDOG.yml have no such rewrite path, so they
may carry comments.

The file must also stay a plain writable file: omp takes a native file lock on
it, and a read-only mode breaks every launch.
"""

from __future__ import annotations

import stat
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from _dotbot import report, repo_root  # noqa: E402

CONFIG = "omp/config.yml"


def main() -> int:
    root = repo_root(sys.argv[1:])
    path = root / CONFIG
    if not path.is_file():
        print(f"SKIP  {CONFIG} absent")
        return 0

    violations = []
    for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if line.lstrip().startswith("#"):
            violations.append(
                f"{CONFIG}:{lineno}: comment — `omp config set` strips it. "
                f"Put the explanation in omp/README.md."
            )

    mode = path.stat().st_mode
    if not mode & stat.S_IWUSR:
        violations.append(f"{CONFIG}: not writable by the owner; omp needs a native file lock on it")

    return report(violations, f"{CONFIG} is writable and comment-free")


if __name__ == "__main__":
    raise SystemExit(main())
