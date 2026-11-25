#!/usr/bin/env python3
"""Merge the tracked shared configs into the machine-local files tools rewrite.

Every tool in TOOLS rewrites its own config. Most save by writing a temp file
and renaming it over the config path, which turns a symlink into a regular file
and makes the next Dotbot run abort its whole link section; Pi writes through
the symlink, which pushes its runtime state (last changelog version, current
model) into git. So each live file stays machine-local and this script
re-applies the tracked keys:

    live  <  repo sources, in row order  <  live-side layers, in row order

Tables merge key by key; scalars and lists replace. Every key the tracked files
do not define survives verbatim. A tool is skipped silently when its live
directory does not exist; mcode is the exception, because it seeds the file even
before the tool has created the directory.

Each write is atomic and 0600, and keeps the previous content next to the live
file as ``<name>.pre-sync``. A leftover symlink is healed into a regular file.

Usage:
    config-merge.py [--dry-run] [--quiet] [tool ...]

With no tool argument every row in ``TOOLS`` is synced. ``--dry-run`` reports
what would change without writing; ``--quiet`` prints only when something
changes. Run it directly for a manual sync; the local step runs it on every
install and every 15-minute tick.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import tomllib
from dataclasses import dataclass
from pathlib import Path

import yaml

REPO = Path(__file__).resolve().parents[1]
SCRIPT = Path(__file__).resolve()
BACKUP_SUFFIX = ".pre-sync"
BARE_KEY = re.compile(r"[A-Za-z0-9_-]+")


@dataclass(frozen=True)
class Tool:
    """One merge target: repo sources, live location, format, dumper options."""

    name: str
    sources: tuple[str, ...]
    directory: str
    filename: str
    fmt: str
    env: str | None = None
    layers: tuple[str, ...] = ()
    sort_keys: bool = False
    indent: int = 2
    require_dir: bool = True


TOOLS = (
    Tool(
        name="codex",
        sources=("codex/config.toml",),
        directory=".codex",
        filename="config.toml",
        fmt="toml",
        env="CODEX_HOME",
        layers=("config_local.toml",),
    ),
    Tool(
        name="mcode",
        sources=("mcode/config.yaml",),
        directory=".minimax",
        filename="config.yaml",
        fmt="yaml",
        env="MCODE_CONFIG_DIR",
        require_dir=False,
    ),
    Tool(
        name="antigravity-cli",
        sources=("antigravity-cli/cli-settings.json",),
        directory=".gemini*/antigravity-cli",
        filename="settings.json",
        fmt="json",
        env="ANTIGRAVITY_CLI_DIR",
        sort_keys=True,
    ),
    Tool(
        name="pi",
        sources=("pi/settings.json",),
        directory=".pi/agent",
        filename="settings.json",
        fmt="json",
    ),
    Tool(
        name="vscode",
        sources=("editors/settings.json", "editors/vscode/settings.json"),
        directory="Library/Application Support/Code/User",
        filename="settings.json",
        fmt="json",
        indent=4,
    ),
    Tool(
        name="cursor",
        sources=("editors/settings.json", "editors/cursor/settings.json"),
        directory="Library/Application Support/Cursor/User",
        filename="settings.json",
        fmt="json",
        indent=4,
    ),
    Tool(
        name="antigravity-ide",
        sources=("editors/settings.json", "editors/antigravity/settings.json"),
        directory="Library/Application Support/Antigravity/User",
        filename="settings.json",
        fmt="json",
        indent=4,
    ),
)

TOOLS_BY_NAME = {tool.name: tool for tool in TOOLS}


def strip_jsonc(text: str) -> str:
    """Drop ``//`` and ``/* */`` comments outside string literals."""
    out: list[str] = []
    index = 0
    in_string = False
    while index < len(text):
        char = text[index]
        if in_string:
            out.append(char)
            if char == "\\":
                if index + 1 < len(text):
                    out.append(text[index + 1])
                index += 2
                continue
            if char == '"':
                in_string = False
            index += 1
            continue
        if char == '"':
            in_string = True
            out.append(char)
            index += 1
            continue
        if text.startswith("//", index):
            while index < len(text) and text[index] != "\n":
                index += 1
            continue
        if text.startswith("/*", index):
            end = text.find("*/", index + 2)
            index = len(text) if end < 0 else end + 2
            continue
        out.append(char)
        index += 1
    return "".join(out)


def load(path: Path, fmt: str) -> dict:
    """Parse one config file; a missing or empty file is an empty mapping."""
    if not path.exists():
        return {}
    text = path.read_text(encoding="utf-8")
    if not text.strip():
        return {}
    if fmt == "toml":
        data = tomllib.loads(text)
    elif fmt == "yaml":
        data = yaml.safe_load(text)
        if data is None:
            return {}
    else:
        data = json.loads(strip_jsonc(text))
    if not isinstance(data, dict):
        raise ValueError("expected a mapping at the top level")
    return data


def merge(base: dict, *layers: dict) -> dict:
    """Deep-merge layers over base; later keys win, nested tables merge."""
    out = dict(base)
    for layer in layers:
        for key, value in layer.items():
            current = out.get(key)
            if isinstance(value, dict) and isinstance(current, dict):
                out[key] = merge(current, value)
            else:
                out[key] = value
    return out


def changed_keys(live: dict, merged: dict, prefix: str = "") -> list[str]:
    """Leaf paths whose value differs between live and merged."""
    out: list[str] = []
    for key, value in merged.items():
        path = f"{prefix}{key}"
        current = live.get(key)
        if isinstance(value, dict) and isinstance(current, dict):
            out.extend(changed_keys(current, value, prefix=f"{path}."))
        elif current != value:
            out.append(path)
    return out


def is_table(value: object) -> bool:
    return isinstance(value, dict)


def is_table_array(value: object) -> bool:
    return isinstance(value, list) and bool(value) and all(isinstance(i, dict) for i in value)


def quote(text: str) -> str:
    return json.dumps(text, ensure_ascii=False)


def fmt_key(key: str) -> str:
    return key if BARE_KEY.fullmatch(key) else quote(key)


def fmt_value(value: object) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, str):
        return quote(value)
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        return repr(value)
    if isinstance(value, list):
        return "[{}]".format(", ".join(fmt_value(item) for item in value))
    raise TypeError(f"unsupported TOML value: {value!r}")


def emit(table: dict, prefix: str, lines: list[str]) -> None:
    """Emit one table: scalar keys first, then sub-tables, then [[arrays]].

    A table that only groups sub-tables gets no header of its own: ``[a.b]``
    already implies ``[a]``, so the shorter form stays byte-for-byte equivalent.
    """
    for key, value in table.items():
        if is_table(value) or is_table_array(value):
            continue
        lines.append(f"{fmt_key(key)} = {fmt_value(value)}")
    for key, value in table.items():
        if is_table(value):
            path = f"{prefix}{fmt_key(key)}"
            if not value or any(not is_table(v) and not is_table_array(v) for v in value.values()):
                lines.append("")
                lines.append(f"[{path}]")
            emit(value, f"{path}.", lines)
    for key, value in table.items():
        if is_table_array(value):
            path = f"{prefix}{fmt_key(key)}"
            for item in value:
                lines.append("")
                lines.append(f"[[{path}]]")
                emit(item, f"{path}.", lines)


def render_toml(tool: Tool, merged: dict, live: Path) -> str:
    header = [
        f"# Machine-local Codex config, regenerated by {SCRIPT}.",
        f"# Shared keys come from {REPO / tool.sources[0]} (tracked in git).",
    ]
    if tool.layers:
        header.append(
            "# Machine-only keys below are preserved as-is; per-machine overrides "
            f"go in {live.with_name(tool.layers[0])}."
        )
    header += [
        "# Do not move this file back into the repo: Codex writes hook trust, project",
        "# trust and marketplace state here at runtime.",
        "",
    ]
    lines: list[str] = []
    emit(merged, "", lines)
    while lines and not lines[0]:
        lines.pop(0)
    return "\n".join(header + lines) + "\n"


def dump(tool: Tool, merged: dict, live: Path) -> str:
    if tool.fmt == "toml":
        return render_toml(tool, merged, live)
    if tool.fmt == "yaml":
        return yaml.safe_dump(
            merged,
            sort_keys=False,
            allow_unicode=True,
            default_flow_style=False,
            # PyYAML folds plain scalars at `width` (and treats <=1 as 80); keep
            # values on one line so the live file stays diff-friendly.
            width=4096,
            indent=2,
        )
    # agy writes settings.json alphabetically sorted; matching that keeps the
    # merge from rewriting the file after every agy save. The editors keep
    # their own key order, which is the order of the tracked base file.
    return (
        json.dumps(merged, indent=tool.indent, sort_keys=tool.sort_keys, ensure_ascii=False)
        + "\n"
    )


def write_atomic(path: Path, text: str) -> None:
    """Write via temp file + rename, the same way the owning tools save."""
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


def live_dirs(tool: Tool) -> list[Path]:
    """Existing live directories for one tool; empty means skip silently."""
    override = os.environ.get(tool.env) if tool.env else None
    if override:
        candidates = [Path(override)]
    elif any(char in tool.directory for char in "*?["):
        candidates = list(Path.home().glob(tool.directory))
    else:
        candidates = [Path.home() / tool.directory]
    if tool.require_dir:
        candidates = [path for path in candidates if path.is_dir()]
    return sorted(candidates)


def sync_one(
    tool: Tool,
    live: Path,
    shared: list[dict],
    *,
    dry_run: bool,
    quiet: bool,
) -> int:
    existed = live.is_file()
    current_text = live.read_text(encoding="utf-8") if existed else None
    try:
        live_data = load(live, tool.fmt)
    except (ValueError, yaml.YAMLError) as exc:
        print(
            f"{tool.name}: {live} is not valid {tool.fmt.upper()} ({exc}); leaving it untouched",
            file=sys.stderr,
        )
        return 1

    overrides = [load(live.with_name(name), tool.fmt) for name in tool.layers]
    merged = merge(live_data, *shared, *overrides)
    text = dump(tool, merged, live)
    symlinked = live.is_symlink()

    if current_text == text and not symlinked:
        if not quiet:
            print(f"{tool.name}: {live} already up to date")
        return 0

    if current_text != text:
        if existed:
            keys = changed_keys(live_data, merged)
            detail = ", ".join(keys[:8]) + (" ..." if len(keys) > 8 else "")
            report = f"{len(keys)} key(s): {detail}" if keys else "no key changes"
            action = "would update" if dry_run else "updated"
            print(f"{tool.name}: {action} {live} ({report})")
        else:
            action = "would seed" if dry_run else "seeded"
            print(f"{tool.name}: {action} {live} from {', '.join(tool.sources)}")
    else:
        action = "would replace" if dry_run else "replaced"
        print(f"{tool.name}: {action} symlink {live} with a regular file")

    if dry_run:
        return 0

    if existed and current_text is not None:
        backup = live.with_name(live.name + BACKUP_SUFFIX)
        backup.write_text(current_text, encoding="utf-8")
        os.chmod(backup, 0o600)

    write_atomic(live, text)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--dry-run", action="store_true", help="report what would change, write nothing"
    )
    parser.add_argument(
        "--quiet", action="store_true", help="only print when something changes"
    )
    parser.add_argument(
        "tools",
        nargs="*",
        metavar="tool",
        choices=list(TOOLS_BY_NAME),
        help="tool to sync (default: all)",
    )
    args = parser.parse_args()

    selected = [TOOLS_BY_NAME[name] for name in args.tools] or list(TOOLS)
    status = 0
    for tool in selected:
        shared: list[dict] = []
        for relative in tool.sources:
            path = REPO / relative
            if not path.exists():
                print(f"{tool.name}: missing tracked config {path}", file=sys.stderr)
                status = 1
                break
            shared.append(load(path, tool.fmt))
        else:
            for directory in live_dirs(tool):
                status |= sync_one(
                    tool,
                    directory / tool.filename,
                    shared,
                    dry_run=args.dry_run,
                    quiet=args.quiet,
                )
    return status


if __name__ == "__main__":
    raise SystemExit(main())
