#!/usr/bin/env python3
"""Merge the tracked mcode config into the live `~/.minimax/config.yaml`.

Why a merge and not a symlink
-----------------------------
mcode saves `config.yaml` by writing a `.config-tmp-<hex>` file next to it and
renaming that temp file **over the config path itself** — the main writer
(`Ht` -> `ux` in the bundled chunks) does not resolve the realpath first. Its
status-line writer does, which is why that one is symlink-safe and this one is
not. So the first thing that writes config turns a symlink at
`~/.minimax/config.yaml` into a regular file: the shift+tab permission picker
(`config.permission.write`), `mcode provider add/remove`, a default-model
change, the legacy BYOK provider migration. dotbot then aborts the entire link
section on the next run with "already exists but is a regular file or
directory". Verified against mcode 0.7.6-preview.

`~/.minimax/config.yaml` therefore stays a real, machine-local file and this
script re-applies the tracked keys on every install and every 15-minute sync.
A leftover symlink is healed automatically: the atomic write below replaces it
with a regular file.

Precedence (highest first)
--------------------------
1. `<repo>/mcode/config.yaml` — shared config, tracked in git
2. `~/.minimax/config.yaml` — live file; every key the repo does not define is
   preserved verbatim (model-discovery results, TUI state, ...)

Tables merge key by key; scalars and lists are replaced by the repo value. That
means a mode toggled in the TUI (`permissionMode`) is reset to the tracked
value on the next sync — the repo is the source of truth for every key it
defines. Edit `mcode/config.yaml` to change one.

Secrets: the tracked file carries `'${MAFIA_API_KEY}'` references, which mcode
expands from its own process environment, so this script never writes key
material into the live file.

Run directly for a manual sync, or through
`scripts/post-install.d/40-mcode-config.sh`.
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

import yaml

REPO = Path(__file__).resolve().parents[1]
SHARED = REPO / "mcode" / "config.yaml"
LIVE = Path(
    os.environ.get("MCODE_CONFIG_DIR") or Path.home() / ".minimax"
) / "config.yaml"
BACKUP_SUFFIX = ".pre-sync"


def load(path: Path) -> dict:
    """Parse a YAML file; a missing or empty file is an empty mapping."""
    if not path.exists():
        return {}
    text = path.read_text(encoding="utf-8")
    data = yaml.safe_load(text)
    if data is None:
        return {}
    if not isinstance(data, dict):
        raise SystemExit(f"{path}: expected a YAML mapping at the top level")
    return data


def merge(live: dict, shared: dict) -> dict:
    """Deep-merge shared into live; shared wins, live-only keys survive."""
    out = dict(live)
    for key, value in shared.items():
        current = out.get(key)
        if isinstance(value, dict) and isinstance(current, dict):
            out[key] = merge(current, value)
        else:
            out[key] = value
    return out


def changed_keys(live: dict, merged: dict, prefix: str = "") -> list[str]:
    """Top-level-ish paths whose value differs between live and merged."""
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
    return yaml.safe_dump(
        data,
        sort_keys=False,
        allow_unicode=True,
        default_flow_style=False,
        # PyYAML folds plain scalars at `width` (and treats <=1 as 80); keep
        # values on one line so the live file stays diff-friendly.
        width=4096,
        indent=2,
    )


def write_atomic(path: Path, text: str) -> None:
    """Write via temp file + rename, the same way mcode itself saves."""
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
        print(f"mcode-config-sync: missing tracked config {SHARED}", file=sys.stderr)
        return 1

    shared = load(SHARED)
    # A broken symlink counts as absent: it gets replaced by a real file.
    existed = LIVE.is_file()
    live = load(LIVE)
    merged = merge(live, shared)
    text = dump(merged)

    current_text = LIVE.read_text(encoding="utf-8") if existed else None

    if current_text == text:
        if not args.quiet:
            print(f"mcode-config-sync: {LIVE} already up to date")
        return 0

    if existed:
        keys = changed_keys(live, merged)
        detail = ", ".join(keys[:8]) + (" ..." if len(keys) > 8 else "")
        action = "would update" if args.dry_run else "updated"
        print(f"mcode-config-sync: {action} {LIVE} ({len(keys)} key(s): {detail})")
    else:
        action = "would seed" if args.dry_run else "seeded"
        print(f"mcode-config-sync: {action} {LIVE} from {SHARED}")

    if args.dry_run:
        return 0

    if existed:
        backup = LIVE.with_name(LIVE.name + BACKUP_SUFFIX)
        backup.write_text(LIVE.read_text(encoding="utf-8"), encoding="utf-8")
        os.chmod(backup, 0o600)

    write_atomic(LIVE, text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
