#!/usr/bin/env python3
"""install.conf.yaml and sync.conf.yaml must declare the same links.

./install reads the first, the 15-minute sync.sh reads the second. A link added
to only one of them works on a fresh machine and silently stops being repaired
afterwards (or the reverse). Deliberate asymmetries live in
.repo-std/link-exemptions.yml, each with a reason.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import yaml  # noqa: E402

from _dotbot import load_links, report, repo_root  # noqa: E402


def main() -> int:
    root = repo_root(sys.argv[1:])
    install = load_links(root / "install.conf.yaml")
    sync = load_links(root / "sync.conf.yaml")

    exempt_file = root / ".repo-std" / "link-exemptions.yml"
    exempt = yaml.safe_load(exempt_file.read_text(encoding="utf-8")) or [] if exempt_file.exists() else []
    exempt_targets = {entry["target"] for entry in exempt}

    violations = []
    for target in sorted(set(install) - set(sync) - exempt_targets):
        violations.append(
            f"{target}: in install.conf.yaml only — the 15-minute sync never repairs it. "
            f"Add it to sync.conf.yaml, or declare it in {exempt_file.name} with a reason."
        )
    for target in sorted(set(sync) - set(install) - exempt_targets):
        violations.append(
            f"{target}: in sync.conf.yaml only — a fresh ./install never creates it. "
            f"Add it to install.conf.yaml, or declare it in {exempt_file.name} with a reason."
        )
    for target in sorted(set(install) & set(sync)):
        if install[target] != sync[target]:
            violations.append(
                f"{target}: the two configs disagree — "
                f"install={install[target]} sync={sync[target]}"
            )
    for target in sorted(exempt_targets - set(install) - set(sync)):
        violations.append(f"{target}: exempted in {exempt_file.name} but no longer linked anywhere — drop the exemption.")

    return report(violations, f"{len(install)} links identical in both configs ({len(exempt_targets)} exempted)")


if __name__ == "__main__":
    raise SystemExit(main())
