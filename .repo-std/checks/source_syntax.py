#!/usr/bin/env python3
"""Every script this repository owns must parse.

./install and sync.sh wrap nearly every step in `|| true`, so a syntax error in
a helper is invisible until the thing it configures is missing. Parsing costs
milliseconds and catches it at commit time.

Scope is the installer machinery this repository maintains, named explicitly.
Skill trees are excluded: they carry third-party scripts whose defects belong to
their upstream, and a gate that fails on someone else's file gets ignored.
"""

from __future__ import annotations

import ast
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from _dotbot import report, repo_root  # noqa: E402

# Paths this repository authors and runs during install/sync or from a linked config.
OWNED = (
    "scripts",
    "install-scripts",
    "wechat-reminder",
    "herdr",
    "self-reflection",
    "mac",
    "claude/hooks",
    "claude/scripts",
    "claude/statusline-command.sh",
    "codex/mihomo",
)


def owned_files(root: Path, suffix: str) -> list[Path]:
    out = subprocess.run(
        ["git", "ls-files", "-z", f"*{suffix}"], cwd=root, capture_output=True, text=True, check=False
    )
    names = [n for n in out.stdout.split("\0") if n] if out.returncode == 0 else []
    if not names:
        names = [str(p.relative_to(root)) for p in root.rglob(f"*{suffix}")]

    paths = []
    for name in names:
        rel = Path(name)
        in_scope = len(rel.parts) == 1 or any(name == d or name.startswith(d + "/") for d in OWNED)
        if in_scope and (root / rel).is_file():
            paths.append(root / rel)
    return paths


def main() -> int:
    root = repo_root(sys.argv[1:])
    violations = []

    shell = owned_files(root, ".sh")
    for path in shell:
        result = subprocess.run(["bash", "-n", str(path)], capture_output=True, text=True, check=False)
        if result.returncode != 0:
            detail = result.stderr.strip().splitlines()[-1] if result.stderr.strip() else "syntax error"
            violations.append(f"{path.relative_to(root)}: {detail}")

    python = owned_files(root, ".py")
    for path in python:
        try:
            ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
        except SyntaxError as exc:
            violations.append(f"{path.relative_to(root)}:{exc.lineno}: {exc.msg}")

    return report(violations, f"{len(shell)} shell and {len(python)} python files parse")


if __name__ == "__main__":
    raise SystemExit(main())
