"""Shared parsing for the two dotbot configs.

Both install.conf.yaml and sync.conf.yaml are a YAML list of single-key blocks.
Only the `link:` blocks matter here. A link entry is either

    ~/.target: source/path

or the expanded form

    ~/.target:
        if: 'test "$(uname)" = Darwin'
        path: source/path

Both are normalised to a dict so callers never branch on the shorthand.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import yaml

CONFIGS = ("install.conf.yaml", "sync.conf.yaml")


def repo_root(argv: list[str] | None = None) -> Path:
    """Resolve --root, defaulting to the repository this file lives in."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=None)
    args = parser.parse_args(argv)
    if args.root:
        return Path(args.root).resolve()
    return Path(__file__).resolve().parents[2]


def load_links(path: Path) -> dict[str, dict]:
    """Return {target: {"path": ..., "if": ...}} for every link entry."""
    if not path.exists():
        return {}
    blocks = yaml.safe_load(path.read_text(encoding="utf-8")) or []
    links: dict[str, dict] = {}
    for block in blocks:
        if not isinstance(block, dict):
            continue
        section = block.get("link")
        if not isinstance(section, dict):
            continue
        for target, spec in section.items():
            links[target] = dict(spec) if isinstance(spec, dict) else {"path": spec}
    return links


def report(violations: list[str], passed: str) -> int:
    """Uniform output contract: one line per violation, exit 1 when any."""
    if violations:
        for line in violations:
            print(f"FAIL  {line}")
        return 1
    print(f"PASS  {passed}")
    return 0
