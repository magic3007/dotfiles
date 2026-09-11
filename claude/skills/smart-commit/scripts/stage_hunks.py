#!/usr/bin/env python3
"""Stage selected hunks (or sub-hunk changes) of one file into the git index.

Use when a staged diff must be split into several commits and `git add -p`
is unavailable or impractical (non-interactive shells, hunk-level surgery
inside a single hunk).

Invariant: the index must equal HEAD for the target file, i.e. run
`git reset` first and never call this twice for the same file in the same
commit.

Examples:
  # inspect hunks
  python3 stage_hunks.py --list trajectory_insights/stages.py

  # stage hunks 0,1,2,4,5 as-is
  python3 stage_hunks.py --take 0,1,2,4,5 trajectory_insights/stages.py

  # hunk 5 mixes two concerns: keep only its 2nd change group
  python3 stage_hunks.py --take 1,2,3 --split 5:1 trajectory_insights/tests/test_pipeline_v2.py
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


def git(repo: Path, args: list[str], **kwargs) -> subprocess.CompletedProcess[str]:
    return subprocess.run(["git", *args], cwd=repo, capture_output=True, text=True, **kwargs)


def parse_diff(text: str) -> tuple[list[str], list[dict]]:
    lines = text.split("\n")
    if lines and lines[-1] == "":
        lines = lines[:-1]
    first = next(index for index, line in enumerate(lines) if line.startswith("@@"))
    hunks: list[dict] = []
    for line in lines[first:]:
        if line.startswith("@@"):
            hunks.append({"header": line, "body": []})
        else:
            hunks[-1]["body"].append(line)
    return lines[:first], hunks


def annotate(body: list[str]) -> list[tuple[str, int | None]]:
    tags: list[tuple[str, int | None]] = []
    group = -1
    index = 0
    while index < len(body):
        line = body[index]
        if line.startswith("-"):
            group += 1
            while index < len(body) and body[index].startswith("-"):
                tags.append(("minus", group))
                index += 1
            while index < len(body) and body[index].startswith("+"):
                tags.append(("plus", group))
                index += 1
        else:
            tags.append(("context", None))
            index += 1
    return tags


def change_groups(body: list[str]) -> list[list[str]]:
    groups: list[list[str]] = []
    for line, (kind, group) in zip(body, annotate(body)):
        if kind == "minus":
            groups.append([])
        if kind in ("minus", "plus"):
            groups[group].append(line)
    return groups


def select_group(body: list[str], keep: int) -> list[str]:
    out: list[str] = []
    for line, (kind, group) in zip(body, annotate(body)):
        if kind == "context":
            out.append(line)
        elif group == keep:
            out.append(line)
        elif kind == "minus":
            out.append(f" {line[1:]}")
    return out


def build_patch(header: list[str], hunks: list[dict], plan: dict[int, set[int]]) -> str:
    out = [line for line in header if not line.startswith("index ")]
    delta = 0
    for index, hunk in enumerate(hunks):
        if index not in plan:
            continue
        body = hunk["body"]
        for keep in sorted(plan[index], reverse=True):
            body = select_group(body, keep)
        start = int(hunk["header"].split()[1].split(",")[0][1:])
        old_count = sum(1 for line in body if line[:1] in (" ", "-"))
        new_count = sum(1 for line in body if line[:1] in (" ", "+"))
        out.append(f"@@ -{start},{old_count} +{start + delta},{new_count} @@")
        out.extend(body)
        delta += new_count - old_count
    return "\n".join(out) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("path", help="path relative to the repository root")
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    parser.add_argument("--list", action="store_true", help="print hunks and change groups, stage nothing")
    parser.add_argument("--take", default="", help="comma separated hunk indices to stage as-is")
    parser.add_argument("--split", action="append", default=[], metavar="HUNK:GROUP[,GROUP]", help="within one hunk keep only these change groups")
    parser.add_argument("--check", action="store_true", help="dry run: only validate that the patch applies")
    args = parser.parse_args()

    if git(args.repo, ["diff", "--cached", "--quiet", "--", args.path]).returncode != 0:
        print(f"error: {args.path} already has staged changes; run `git reset` first", file=sys.stderr)
        return 2
    diff = git(args.repo, ["diff", "HEAD", "--", args.path]).stdout
    if not diff.strip():
        print(f"error: no changes for {args.path}", file=sys.stderr)
        return 2
    header, hunks = parse_diff(diff)

    if args.list:
        for index, hunk in enumerate(hunks):
            print(f"hunk{index}: {hunk['header']}")
            for group, changes in enumerate(change_groups(hunk["body"])):
                lines = [line for line in changes if line.startswith("+")] or changes
                print(f"    group{group}: {len(changes)} line(s)  {lines[0][:100]}")
        return 0

    plan: dict[int, set[int]] = {int(index): set() for index in args.take.split(",") if index.strip()}
    for spec in args.split:
        hunk_index, _, groups = spec.partition(":")
        plan.setdefault(int(hunk_index), set())
        plan[int(hunk_index)].update(int(group) for group in groups.split(",") if group.strip())
    unknown = [index for index in plan if not 0 <= index < len(hunks)]
    if unknown:
        print(f"error: hunk index out of range: {unknown}", file=sys.stderr)
        return 2

    patch = args.repo / f".stage-hunks-{Path(args.path).name}.patch"
    patch.write_text(build_patch(header, hunks, plan))
    try:
        command = ["apply", "--cached"] + (["--check"] if args.check else []) + [str(patch)]
        result = git(args.repo, command)
        if result.returncode:
            print(f"error: patch did not apply\n{result.stderr}", file=sys.stderr)
            return 1
    finally:
        patch.unlink(missing_ok=True)
    action = "validated" if args.check else "staged"
    print(f"{action} hunks {sorted(plan)} of {len(hunks)} for {args.path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
