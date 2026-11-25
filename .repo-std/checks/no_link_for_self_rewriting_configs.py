#!/usr/bin/env python3
"""Configs their owning tool rewrites in place must never be symlinked.

Those tools save by writing a temp file and renaming it over the config path,
without resolving the realpath first. The rename replaces the symlink with a
regular file; machine-local state then sits in the repository, and the next
dotbot run aborts the whole link section with "already exists but is a regular
file or directory".

The repository handles each of these by merging (scripts/*-sync.py) or by
seeding (scripts/post-install.d/10-seed-configs.sh) instead. Observed for Codex,
kimi, mcode, the Antigravity CLI and the Herdr app.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from _dotbot import CONFIGS, load_links, report, repo_root  # noqa: E402

# Written out here rather than derived from the configs: a guard that reads the
# source it guards only proves the source agrees with itself.
SELF_REWRITING = {
    "~/.codex/config.toml": "Codex writes [projects.*] trust and [hooks.state] into it",
    "~/.minimax/config.yaml": "mcode saves via .config-tmp-<hex> + rename over the config path",
    "~/.kimi-code/config.toml": "the kimi CLI rewrites it with an atomic write + rename",
    "~/.gemini/antigravity-cli/settings.json": "agy rewrites it on every /config change and permission grant",
    "~/.config/herdr-app/settings.json": "herdr-app writes it via temp file + rename",
    "~/.config/herdr-app/keys.json": "herdr-app writes it via temp file + rename",
}


def main() -> int:
    root = repo_root(sys.argv[1:])
    violations = []

    for config in CONFIGS:
        links = load_links(root / config)
        for target, reason in SELF_REWRITING.items():
            if target in links:
                violations.append(
                    f"{config}: {target} is linked, but {reason}. "
                    f"Merge or seed it instead — see docs/REPO_GUIDE.md."
                )

    return report(violations, f"{len(SELF_REWRITING)} self-rewriting configs stay unlinked")


if __name__ == "__main__":
    raise SystemExit(main())
