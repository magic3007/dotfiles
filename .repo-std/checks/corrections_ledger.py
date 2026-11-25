#!/usr/bin/env python3
"""The ledger and the checks must describe each other exactly.

This is the guard that keeps the other guards honest. Without it the ledger
drifts back into prose: a correction gets written down with no check behind it,
or a check is renamed and the lesson it defended is quietly undefended — which
is worse than never having written it down.

Three assertions:
  - every check has a ledger entry stating the correction it came from;
  - every ledger entry names a check that exists;
  - every check has a violating fixture, so the negative control is runnable.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import yaml  # noqa: E402

from _lib import report, repo_root  # noqa: E402

REQUIRED_FIELDS = ("origin", "rule", "check")


def main() -> int:
    root = repo_root(sys.argv[1:])
    std = root / ".repo-std"
    ledger_path = std / "corrections.yml"

    if not ledger_path.is_file():
        print(f"FAIL  {ledger_path.relative_to(root)} is missing")
        return 1

    entries = yaml.safe_load(ledger_path.read_text(encoding="utf-8")) or []
    checks = {p.stem for p in (std / "checks").glob("*.py") if not p.name.startswith("_")}

    violations = []
    registered = set()

    for index, entry in enumerate(entries):
        where = f"corrections.yml[{index}]"
        if not isinstance(entry, dict):
            violations.append(f"{where}: not a mapping")
            continue
        for field in REQUIRED_FIELDS:
            if not str(entry.get(field, "")).strip():
                violations.append(f"{where}: empty or missing `{field}`")
        name = entry.get("check")
        if not name:
            continue
        registered.add(name)
        if name not in checks:
            violations.append(
                f"{where}: names check {name!r}, which does not exist — "
                f"the correction it recorded is now undefended"
            )
            continue
        fixture = std / "checks" / "fixtures" / name
        if not fixture.is_dir():
            violations.append(
                f"{where}: no violating fixture at {fixture.relative_to(root)}; "
                f"a guard that has never failed is a guard nobody tested"
            )

    for orphan in sorted(checks - registered):
        violations.append(
            f"checks/{orphan}.py: not in corrections.yml — record which correction it enforces"
        )

    return report(violations, f"{len(checks)} checks, each with a ledger entry and a fixture")


if __name__ == "__main__":
    raise SystemExit(main())
