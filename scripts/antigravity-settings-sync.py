#!/usr/bin/env python3
"""Merge the tracked Antigravity CLI settings into the live `settings.json`.

Why a merge and not a symlink
-----------------------------
`agy` owns `~/.gemini/antigravity-cli/settings.json` and rewrites it whenever a
setting changes (`/config`, the model picker, workspace trust, permissions
granted during a session). The file also carries machine-local state such as
`trustedWorkspaces` and the selected `model`. A symlink into this repo would
push that state into git and would be replaced by a regular file on the first
write anyway. So the live file stays machine-local and this script re-applies
the tracked keys on every install and every 15-minute sync.

Precedence (highest first)
--------------------------
1. `<repo>/antigravity/cli-settings.json` — shared keys, tracked in git
2. `~/.gemini/antigravity-cli/settings.json` — live file; every key the repo
   does not define is preserved verbatim

Tracked keys that matter:
  toolPermission        "always-proceed" | "request-review" | "strict" |
                        "proceed-in-sandbox" — tool confirmation policy
  artifactReviewPolicy  "always-proceed" | ... — plan/artifact review policy

Run directly for a manual sync, or through
`scripts/post-install.d/60-antigravity-settings.sh`.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
SHARED = REPO / "antigravity" / "cli-settings.json"
BACKUP_SUFFIX = ".pre-sync"


def resolve_targets() -> list[Path]:
    override = os.environ.get("ANTIGRAVITY_CLI_DIR")
    if override:
        return [Path(override) / "settings.json"]
    targets = [
        p / "antigravity-cli" / "settings.json"
        for p in sorted(Path.home().glob(".gemini*"))
        if p.is_dir() and (p / "antigravity-cli").is_dir()
    ]
    return targets or [Path.home() / ".gemini" / "antigravity-cli" / "settings.json"]


def load(path: Path) -> dict:
    if not path.exists():
        return {}
    text = path.read_text(encoding="utf-8")
    if not text.strip():
        return {}
    data = json.loads(text)
    if not isinstance(data, dict):
        raise SystemExit(f"{path}: expected a JSON object at the top level")
    return data


def merge(live: dict, shared: dict) -> dict:
    out = dict(live)
    for key, value in shared.items():
        current = out.get(key)
        if isinstance(value, dict) and isinstance(current, dict):
            out[key] = merge(current, value)
        else:
            out[key] = value
    return out


def changed_keys(live: dict, merged: dict, prefix: str = "") -> list[str]:
    out: list[str] = []
    for key, value in merged.items():
        path = f"{prefix}{key}"
        current = live.get(key)
        if isinstance(value, dict) and isinstance(current, dict):
            out.extend(changed_keys(current, value, prefix=f"{path}."))
        elif current != value:
            out.append(path)
    return out


def dump(data: dict) -> str:
    # agy writes settings.json with alphabetically sorted keys; matching that
    # keeps the merge from rewriting the file after every agy save.
    return json.dumps(data, indent=2, sort_keys=True, ensure_ascii=False) + "\n"


def write_atomic(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f".{path.name}.sync-tmp-{os.getpid()}")
    try:
        fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(text)
        os.replace(tmp, path)
    except BaseException:
        tmp.unlink(missing_ok=True)
        raise


def sync_one(live_path: Path, shared: dict, *, dry_run: bool, quiet: bool) -> int:
    existed = live_path.is_file()
    current_text = live_path.read_text(encoding="utf-8") if existed else None
    try:
        live = load(live_path)
    except json.JSONDecodeError as exc:
        print(
            f"antigravity-settings-sync: {live_path} is not valid JSON ({exc}); "
            "leaving it untouched",
            file=sys.stderr,
        )
        return 1

    merged = merge(live, shared)
    text = dump(merged)

    if current_text == text:
        if not quiet:
            print(f"antigravity-settings-sync: {live_path} already up to date")
        return 0

    if existed:
        keys = changed_keys(live, merged)
        detail = ", ".join(keys[:8]) + (" ..." if len(keys) > 8 else "")
        action = "would update" if dry_run else "updated"
        print(f"antigravity-settings-sync: {action} {live_path} ({len(keys)} key(s): {detail})")
    else:
        action = "would seed" if dry_run else "seeded"
        print(f"antigravity-settings-sync: {action} {live_path} from {SHARED}")

    if dry_run:
        return 0

    if existed and current_text is not None:
        backup = live_path.with_name(live_path.name + BACKUP_SUFFIX)
        backup.write_text(current_text, encoding="utf-8")
        os.chmod(backup, 0o600)

    write_atomic(live_path, text)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--dry-run", action="store_true", help="report what would change, write nothing"
    )
    parser.add_argument(
        "--quiet", action="store_true", help="only print when something changes"
    )
    args = parser.parse_args()

    if not SHARED.exists():
        print(
            f"antigravity-settings-sync: missing tracked settings {SHARED}",
            file=sys.stderr,
        )
        return 1

    shared = load(SHARED)
    rc = 0
    for target in resolve_targets():
        rc |= sync_one(target, shared, dry_run=args.dry_run, quiet=args.quiet)
    return rc


if __name__ == "__main__":
    raise SystemExit(main())
