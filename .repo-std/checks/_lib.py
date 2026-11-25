"""Shared helpers and facts for the checks: one definition each.

Output contract: one `FAIL  ` line per violation and exit 1, or one `PASS  `
line and exit 0 (see report()). gate.sh --prove relies on the FAIL lines.
"""

from __future__ import annotations

import argparse
import subprocess
from pathlib import Path

import yaml

CONFIG = "install.conf.yaml"

SKILL_SOURCES = ("skills", "claude/skills", "codex/skills", "pi/skills", "omp/skills")

VENDORED = (
    "skills/scientific-agent-skills",
    "dotbot",
    "vim/vimrc",
    "neovim/nvim-basic-ide",
    "ranger/plugins/ranger_devicons",
    "ranger/commands_full.py",
    "terminals/tmux.conf",
    "gdb/gdbinit_dashboard",
    "gdb/gdbinit_dbinit_stl_views",
    "obsidian/plugins/claudian",
    "claude/skills/web-access",
    "omp/skills/skill-creator",
)


def repo_root(argv: list[str] | None = None) -> Path:
    """Resolve --root, defaulting to the repository this file lives in."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=None)
    args = parser.parse_args(argv)
    if args.root:
        return Path(args.root).resolve()
    return Path(__file__).resolve().parents[2]


def report(violations: list[str], passed: str) -> int:
    if violations:
        for line in violations:
            print(f"FAIL  {line}")
        return 1
    print(f"PASS  {passed}")
    return 0


def is_vendored(rel: str) -> bool:
    return any(rel == v or rel.startswith(v + "/") for v in VENDORED)


def owned_files(root: Path, suffix: str = "") -> list[str]:
    """Repository-relative paths of tracked files, minus vendored trees and the
    checks' own fixtures. Outside a checkout (a fixture) every file counts."""
    out = subprocess.run(
        ["git", "ls-files", "-z", f"*{suffix}"], cwd=root, capture_output=True, text=True, check=False
    )
    names = [n for n in out.stdout.split("\0") if n] if out.returncode == 0 else []
    if not names:
        names = [p.relative_to(root).as_posix() for p in root.rglob(f"*{suffix}") if p.is_file()]
    return [n for n in names if not n.startswith(".repo-std/") and not is_vendored(n) and (root / n).is_file()]


def load_links(root: Path) -> dict[str, dict]:
    """Return {target: {"path": ..., "if": ...}} for every link in the dotbot config.

    An entry is either `~/.target: source` or the expanded form with `path:` and
    optional `if:`; both come back as a dict.
    """
    path = root / CONFIG
    if not path.exists():
        return {}
    links: dict[str, dict] = {}
    for block in yaml.safe_load(path.read_text(encoding="utf-8")) or []:
        section = block.get("link") if isinstance(block, dict) else None
        if isinstance(section, dict):
            for target, spec in section.items():
                links[target] = dict(spec) if isinstance(spec, dict) else {"path": spec}
    return links
