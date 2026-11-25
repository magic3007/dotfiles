#!/usr/bin/env python3
"""Every script this repository owns must parse.

./install and sync.sh wrap nearly every step in `|| true`, so a syntax error in
a helper is invisible until the thing it configures is missing. Parsing costs
milliseconds and catches it at commit time.

Scope is every tracked file outside the vendored trees listed in _lib.VENDORED:
their defects belong to their upstream.
"""

from __future__ import annotations

import ast
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from _lib import owned_files, report, repo_root  # noqa: E402


def main() -> int:
    root = repo_root(sys.argv[1:])
    violations = []

    shell = owned_files(root, ".sh")
    for name in shell:
        result = subprocess.run(["bash", "-n", name], cwd=root, capture_output=True, text=True, check=False)
        if result.returncode != 0:
            detail = result.stderr.strip().splitlines()[-1] if result.stderr.strip() else "syntax error"
            violations.append(f"{name}: {detail}")

    python = owned_files(root, ".py")
    for name in python:
        try:
            ast.parse((root / name).read_text(encoding="utf-8"), filename=name)
        except SyntaxError as exc:
            violations.append(f"{name}:{exc.lineno}: {exc.msg}")

    return report(violations, f"{len(shell)} shell and {len(python)} python files parse")


if __name__ == "__main__":
    raise SystemExit(main())
