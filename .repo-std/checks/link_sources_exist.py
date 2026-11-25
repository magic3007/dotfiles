#!/usr/bin/env python3
"""Every link source must exist in the repository.

A missing source makes dotbot print `Nonexistent source ~/.x -> y` and end the
whole run with "Some tasks were not executed successfully".
Sources outside the repository (paths starting with ~ or /) are installed by
other steps and are checked for their shape only.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from _dotbot import CONFIGS, load_links, report, repo_root  # noqa: E402


def main() -> int:
    root = repo_root(sys.argv[1:])
    violations = []
    checked = 0

    for config in CONFIGS:
        for target, spec in load_links(root / config).items():
            source = spec.get("path")
            if not source:
                violations.append(f"{config}: {target} has no path")
                continue
            if source.startswith(("~", "/")):
                continue
            checked += 1
            if not (root / source).exists():
                violations.append(
                    f"{config}: {target} -> {source} does not exist; "
                    f"dotbot aborts the link section with 'Nonexistent source'"
                )

    return report(violations, f"{checked} in-repo link sources exist")


if __name__ == "__main__":
    raise SystemExit(main())
