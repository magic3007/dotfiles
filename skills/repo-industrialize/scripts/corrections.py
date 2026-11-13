#!/usr/bin/env python3
"""Corrections ledger: every past correction must own a deterministic check.

The ledger lives at <repo>/.repo-std/corrections.yml. Documentation is never a
valid enforcement: an entry is either backed by a runnable command or explicitly
waived with a review hook and a revisit date.

Usage:
    python corrections.py verify [--ledger PATH]
    python corrections.py run    [--ledger PATH] [--id C001]
    python corrections.py prove  [--ledger PATH] [--id C001]
    python corrections.py list   [--ledger PATH]
    python corrections.py add --rule R --origin O --run CMD [--prove CMD] [...]
"""
from __future__ import annotations

import argparse
import datetime as dt
import re
import subprocess
import sys
from pathlib import Path

import yaml

DEFAULT_LEDGER = Path(".repo-std/corrections.yml")
ENFORCEMENT_KINDS = {"script", "lint", "test", "ci"}
REJECTED_KINDS = {"doc", "docs", "review", "guideline", "readme", "rule", "convention"}
ID_RE = re.compile(r"^C\d{3,}$")
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


class LedgerError(Exception):
    pass


def load(path: Path) -> dict:
    if not path.is_file():
        raise LedgerError(f"ledger not found: {path}")
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    if not isinstance(data, dict) or not isinstance(data.get("corrections"), list):
        raise LedgerError(f"{path}: expected a mapping with a 'corrections' list")
    return data


def dump(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        yaml.safe_dump(data, allow_unicode=True, sort_keys=False, width=100),
        encoding="utf-8",
    )


def validate_entry(item: object, label: str) -> list[str]:
    problems: list[str] = []
    if not isinstance(item, dict):
        return [f"{label}: entry is not a mapping"]
    if not ID_RE.match(str(item.get("id", ""))):
        problems.append(f"{label}: id must match C001 形式")
    for field in ("origin", "rule", "date"):
        if not str(item.get(field, "")).strip():
            problems.append(f"{label}: missing {field}")
    if item.get("date") and not DATE_RE.match(str(item["date"])):
        problems.append(f"{label}: date must be YYYY-MM-DD")

    status = item.get("status")
    if status not in {"enforced", "waived"}:
        return problems + [f"{label}: status must be enforced or waived"]

    enforcement = item.get("enforcement") or {}
    if status == "enforced":
        kind = str(enforcement.get("kind", "")).lower()
        if kind in REJECTED_KINDS:
            problems.append(
                f"{label}: kind={kind!r} 只是文字约定，不是确定性检查；"
                "改成 script/lint/test/ci，或把 status 改成 waived 并填 waiver"
            )
        elif kind not in ENFORCEMENT_KINDS:
            problems.append(f"{label}: enforcement.kind must be one of {sorted(ENFORCEMENT_KINDS)}")
        if not str(enforcement.get("run", "")).strip():
            problems.append(f"{label}: enforcement.run 必须是干净仓库上退出码为 0 的命令")
        if not str(enforcement.get("prove", "")).strip() and not str(
            enforcement.get("prove_evidence", "")
        ).strip():
            problems.append(
                f"{label}: 需要 enforcement.prove（对违规样本必须失败的命令）"
                "或 enforcement.prove_evidence（红→绿观测记录）"
            )
    else:
        waiver = item.get("waiver") or {}
        if enforcement:
            problems.append(f"{label}: waived 条目不得同时声明 enforcement")
        for field in ("reason", "surfaced_in", "revisit"):
            if not str(waiver.get(field, "")).strip():
                problems.append(f"{label}: waiver.{field} 必填")
        if waiver.get("revisit") and not DATE_RE.match(str(waiver["revisit"])):
            problems.append(f"{label}: waiver.revisit must be YYYY-MM-DD")
    return problems


def validate(data: dict) -> list[str]:
    problems: list[str] = []
    seen: set[str] = set()
    for index, item in enumerate(data["corrections"]):
        label = (item.get("id") if isinstance(item, dict) else None) or f"#{index}"
        problems += validate_entry(item, label)
        if isinstance(item, dict) and ID_RE.match(str(item.get("id", ""))):
            if item["id"] in seen:
                problems.append(f"{label}: duplicate id")
            seen.add(item["id"])
    return problems


def run_command(command: str, cwd: Path) -> tuple[int, str]:
    try:
        completed = subprocess.run(
            command, shell=True, cwd=cwd, capture_output=True, text=True, timeout=900
        )
    except subprocess.SubprocessError as exc:
        return 127, str(exc)
    output = (completed.stdout + completed.stderr).strip()
    return completed.returncode, output


def selected(data: dict, only: str | None, status: str | None = None) -> list[dict]:
    items = data["corrections"]
    if only:
        items = [item for item in items if item.get("id") == only]
        if not items:
            raise LedgerError(f"no correction with id {only}")
    if status:
        items = [item for item in items if item.get("status") == status]
    return items


def report(rows: list[tuple[str, str, str]]) -> None:
    width = max((len(row[0]) for row in rows), default=2)
    for ident, verdict, detail in rows:
        print(f"{ident.ljust(width)}  {verdict}  {detail}")


def cmd_verify(args, data: dict, root: Path) -> int:
    problems = validate(data)
    enforced = sum(1 for i in data["corrections"] if i.get("status") == "enforced")
    waived = sum(1 for i in data["corrections"] if i.get("status") == "waived")
    for problem in problems:
        print(f"FAIL {problem}")
    print(f"{len(data['corrections'])} 条纠正：enforced={enforced} waived={waived}")
    stale = [
        i["id"] for i in data["corrections"]
        if i.get("status") == "waived"
        and DATE_RE.match(str((i.get("waiver") or {}).get("revisit", "")))
        and str((i.get("waiver") or {}).get("revisit")) < dt.date.today().isoformat()
    ]
    if stale:
        print(f"FAIL 豁免已过复查日期，必须重新裁决：{', '.join(stale)}")
        problems.append("stale waivers")
    return 1 if problems else 0


def cmd_run(args, data: dict, root: Path) -> int:
    items = selected(data, args.id, status="enforced")
    rows, failed = [], 0
    for item in items:
        command = item["enforcement"]["run"]
        code, output = run_command(command, root)
        if code == 0:
            rows.append((item["id"], "PASS", command))
        else:
            failed += 1
            rows.append((item["id"], "FAIL", f"{command} → exit {code}\n{output}"))
    report(rows)
    print(f"{len(items) - failed}/{len(items)} 项检查通过")
    return 1 if failed else 0


def cmd_prove(args, data: dict, root: Path) -> int:
    items = selected(data, args.id, status="enforced")
    rows, failed = [], 0
    for item in items:
        enforcement = item["enforcement"]
        command = enforcement.get("prove")
        if not command:
            rows.append((item["id"], "SKIP", f"仅有观测记录：{enforcement.get('prove_evidence')}"))
            continue
        code, output = run_command(command, root)
        if code != 0:
            rows.append((item["id"], "PASS", f"{command} → exit {code}（按预期失败）"))
        else:
            failed += 1
            rows.append((item["id"], "FAIL", f"{command} 在违规样本上退出 0，检查抓不到问题\n{output}"))
    report(rows)
    print(f"{failed} 项反向验证失败")
    return 1 if failed else 0


def cmd_list(args, data: dict, root: Path) -> int:
    for item in data["corrections"]:
        enforcement = item.get("enforcement") or {}
        tail = enforcement.get("run") or (item.get("waiver") or {}).get("surfaced_in", "")
        print(f"{item.get('id')}  {item.get('status'):8}  {item.get('rule')}  ← {tail}")
    return 0


def cmd_add(args, data: dict, root: Path) -> int:
    numbers = [int(i["id"][1:]) for i in data["corrections"] if ID_RE.match(str(i.get("id", "")))]
    new_id = f"C{max(numbers, default=0) + 1:03d}"
    entry = {
        "id": new_id,
        "date": args.date or dt.date.today().isoformat(),
        "origin": args.origin,
        "rule": args.rule,
        "status": "waived" if args.waive_reason else "enforced",
    }
    if args.waive_reason:
        entry["waiver"] = {
            "reason": args.waive_reason,
            "surfaced_in": args.surfaced_in or "",
            "revisit": args.revisit or "",
        }
    else:
        enforcement = {"kind": args.kind, "run": args.run}
        if args.prove:
            enforcement["prove"] = args.prove
        if args.prove_evidence:
            enforcement["prove_evidence"] = args.prove_evidence
        entry["enforcement"] = enforcement
    problems = validate_entry(entry, new_id)
    if problems:
        for problem in problems:
            print(f"FAIL {problem}")
        return 1
    data["corrections"].append(entry)
    dump(args.ledger, data)
    print(f"added {new_id} to {args.ledger}")
    remaining = len(validate(data))
    if remaining:
        print(f"注意：台账另有 {remaining} 处既有问题，运行 verify 查看")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    sub = parser.add_subparsers(dest="command", required=True)
    for name, handler in (("verify", cmd_verify), ("list", cmd_list)):
        sub.add_parser(name).set_defaults(handler=handler)
    for name, handler in (("run", cmd_run), ("prove", cmd_prove)):
        child = sub.add_parser(name)
        child.add_argument("--id")
        child.set_defaults(handler=handler)
    add = sub.add_parser("add")
    add.add_argument("--rule", required=True)
    add.add_argument("--origin", required=True)
    add.add_argument("--date")
    add.add_argument("--kind", default="script", choices=sorted(ENFORCEMENT_KINDS))
    add.add_argument("--run", default="")
    add.add_argument("--prove", default="")
    add.add_argument("--prove-evidence", dest="prove_evidence", default="")
    add.add_argument("--waive-reason", dest="waive_reason", default="")
    add.add_argument("--surfaced-in", dest="surfaced_in", default="")
    add.add_argument("--revisit", default="")
    add.set_defaults(handler=cmd_add)
    args = parser.parse_args()

    ledger = args.ledger.resolve()
    root = ledger.parent.parent if ledger.parent.name == ".repo-std" else Path.cwd()
    try:
        data = load(ledger) if ledger.is_file() else {"version": 1, "corrections": []}
        if not ledger.is_file() and args.command != "add":
            raise LedgerError(f"ledger not found: {ledger}")
        return args.handler(args, data, root)
    except LedgerError as exc:
        print(f"FAIL {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
