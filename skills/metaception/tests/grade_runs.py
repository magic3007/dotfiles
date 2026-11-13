#!/usr/bin/env python3
"""给 metaception iteration-1 的 6 个 run 打分。

每条断言都机器判定，避免评审口味进入指标。判定对象是 run 的 outputs/ 目录：
产出的技能文件（*.md，排除 report.md）与 report.md。
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

VALIDATOR = Path("/home/yanzhou/dotfiles/skills/metaception/scripts/validate_skill.py")
FORM_VOCAB = {"eliminate", "type", "test", "lint", "hook", "ci", "runtime-assert", "command"}
EMPTY = re.compile(r"^(missing|todo|tbd|n/?a|待补|待验证|无|没做|-+|—+|\?+)$", re.I)


def skill_files(out: Path) -> list[Path]:
    return [p for p in out.rglob("*.md") if p.name.lower() != "report.md"]


def body(out: Path) -> str:
    return "\n".join(p.read_text(encoding="utf-8") for p in skill_files(out))


def report(out: Path) -> str:
    p = out / "report.md"
    return p.read_text(encoding="utf-8") if p.is_file() else ""


def section(text: str, names: list[str]) -> str:
    """取二级标题下的内容，直到下一个二级标题。"""
    pat = r"^##\s*(" + "|".join(names) + r")\b(.*?)(?=^##\s|\Z)"
    m = re.search(pat, text, re.I | re.M | re.S)
    return m.group(2) if m else ""


def rows(sec: str) -> tuple[list[str], list[list[str]]]:
    """只取该段里的第一个表格，和校验器 parse_md_table 的口径保持一致。"""
    header: list[str] = []
    out: list[list[str]] = []
    started = False
    for line in sec.splitlines():
        s = line.strip()
        is_row = s.startswith("|") and s.endswith("|")
        if not is_row:
            if started:
                break
            continue
        started = True
        if re.fullmatch(r"[:\-\s|]+", s.strip("|")):
            continue
        cells = [c.strip() for c in s.strip("|").split("|")]
        if not header:
            header = cells
        else:
            out.append(cells)
    return header, out


def col(header: list[str], pat: str) -> int | None:
    for i, h in enumerate(header):
        if re.search(pat, h, re.I):
            return i
    return None


def run_validator(out: Path) -> tuple[int, str]:
    files = skill_files(out)
    if not files:
        return 2, "no skill file"
    r = subprocess.run(
        [sys.executable, str(VALIDATOR), str(files[0])],
        capture_output=True, text=True,
    )
    return r.returncode, r.stdout[-2000:]


def check_rows(out: Path) -> tuple[list[str], list[list[str]]]:
    return rows(section(body(out), ["Checks", "检查", "可执行.*", "确定性检查"]))


def grade_eval0(out: Path) -> list[dict]:
    b = body(out)
    header, rs = check_rows(out)
    res = []
    res.append({"text": "产出含 ## Checks 章节", "passed": bool(header),
                "evidence": f"表头: {header}" if header else "未找到 Checks 表"})
    res.append({"text": "Checks 表至少 3 行（会话有 ≥3 条可自动化纠正）", "passed": len(rs) >= 3,
                "evidence": f"{len(rs)} 行"})
    ni = col(header, r"负控|negative")
    withneg = [r for r in rs if ni is not None and ni < len(r) and r[ni] and not EMPTY.match(r[ni])]
    res.append({"text": "每条检查都有非空负控（非 MISSING/TODO）",
                "passed": bool(rs) and len(withneg) == len(rs),
                "evidence": f"{len(withneg)}/{len(rs)} 行有负控"})
    fi = col(header, r"形态|form")
    forms = [r[fi].strip().strip("`").lower() for r in rs if fi is not None and fi < len(r)]
    bad = [f for f in forms if f and f not in FORM_VOCAB]
    res.append({"text": "形态词全部取自受控词表", "passed": bool(forms) and not bad,
                "evidence": f"形态={forms}" + (f"，表外={bad}" if bad else "")})
    sed_row = [r for r in rs if re.search(r"sed\s+-i|流编辑器|perl\s+-pi", " ".join(r), re.I)]
    res.append({"text": "「禁止用流编辑器改源码」落成一条检查，而不只是散文",
                "passed": bool(sed_row),
                "evidence": sed_row[0][:2] if sed_row else "Checks 表内无该行"})
    sync_row = [r for r in rs if re.search(r"config_sync", " ".join(r), re.I)]
    res.append({"text": "「提交前跑 config_sync.py --check」落成检查（hook/ci/command 形态）",
                "passed": bool(sync_row),
                "evidence": sync_row[0][:2] if sync_row else "Checks 表内无该行"})
    code, _ = run_validator(out)
    res.append({"text": "validate_skill.py 退出码 0", "passed": code == 0, "evidence": f"exit={code}"})
    res.append({"text": "未出现「记得/务必」类人肉提醒", "passed": not re.search(r"记得|务必|切记|不要忘", b),
                "evidence": "clean" if not re.search(r"记得|务必|切记|不要忘", b) else "命中提醒措辞"})
    return res


def grade_eval1(out: Path) -> list[dict]:
    b = body(out)
    header, rs = check_rows(out)
    res = []
    res.append({"text": "产出含 ## Checks 章节", "passed": bool(header),
                "evidence": f"表头: {header}" if header else "未找到 Checks 表"})
    tz_row = [r for r in rs if re.search(r"tz|时区|timezone|astimezone", " ".join(r), re.I)]
    res.append({"text": "时区 bug 落成一条检查（回归测试/类型约束等）", "passed": bool(tz_row),
                "evidence": tz_row[0][:3] if tz_row else "Checks 表内无时区相关行"})
    ni = col(header, r"负控|negative")
    withneg = [r for r in rs if ni is not None and ni < len(r) and r[ni] and not EMPTY.match(r[ni])]
    res.append({"text": "每条检查都有非空负控", "passed": bool(rs) and len(withneg) == len(rs),
                "evidence": f"{len(withneg)}/{len(rs)} 行有负控"})
    nonauto = section(b, ["Checks", "检查", "可执行.*", "确定性检查"])
    taste = re.search(r"(先给结论|结论.*过程|报告.*结论)", nonauto)
    reason = re.search(r"不可行|无法自动化|审美|不可判定|无机器信号", nonauto)
    res.append({"text": "「报告先给结论」这条审美纠正落进「无法自动化」表并写明理由",
                "passed": bool(taste and reason),
                "evidence": f"taste={bool(taste)} reason={bool(reason)}"})
    res.append({"text": "Facts 逐字保留 CI 断言串 '2026-03-02' == '2026-03-01'",
                "passed": "'2026-03-02' == '2026-03-01'" in b,
                "evidence": "found" if "'2026-03-02' == '2026-03-01'" in b else "missing"})
    code, _ = run_validator(out)
    res.append({"text": "validate_skill.py 退出码 0", "passed": code == 0, "evidence": f"exit={code}"})
    return res


def grade_eval2(out: Path) -> list[dict]:
    files = skill_files(out)
    rep = report(out)
    refused = bool(re.search(r"不抽取|拒绝抽取|no extraction|not extract", rep))
    res = [
        {"text": "未产出新技能文件（避免过度抽取）", "passed": not files,
         "evidence": f"产出文件: {[f.name for f in files]}" if files else "仅 report.md"},
        {"text": "report 明确判定为不抽取", "passed": refused,
         "evidence": "found refusal" if refused else "无明确拒绝判定"},
        {"text": "report 给出拒绝理由（引用拒绝条款）",
         "passed": bool(re.search(r"查文档|文档就能|一次性|不可复用|无纠正|trivial|非显然", rep)),
         "evidence": "has reason" if re.search(r"查文档|文档就能|一次性|不可复用|无纠正|trivial|非显然", rep) else "无理由"},
    ]
    return res


GRADERS = {
    "eval-0-corrections-to-checks": grade_eval0,
    "eval-1-debug-plus-taste": grade_eval1,
    "eval-2-trivial-no-extract": grade_eval2,
}


def main() -> int:
    root = Path(sys.argv[1])
    for eval_dir in sorted(root.iterdir()):
        if not eval_dir.is_dir() or eval_dir.name not in GRADERS:
            continue
        for arm in ("with_skill", "old_skill"):
            out = eval_dir / arm / "run-1" / "outputs"
            if not out.is_dir():
                continue
            exps = GRADERS[eval_dir.name](out)
            passed = sum(1 for e in exps if e["passed"])
            timing_file = eval_dir / arm / "run-1" / "timing.json"
            timing = json.loads(timing_file.read_text()) if timing_file.is_file() else {}
            data = {
                "run_id": f"{eval_dir.name}-{arm}",
                "eval_id": eval_dir.name,
                "run_number": 1,
                "expectations": exps,
                "summary": {
                    "passed": passed,
                    "failed": len(exps) - passed,
                    "total": len(exps),
                    "pass_rate": round(passed / len(exps), 3) if exps else 0.0,
                },
                "time_seconds": timing.get("total_duration_seconds", 0) or 0,
                "tokens": timing.get("total_tokens") or 0,
                "tool_calls": 0,
                "errors": 0,
                "notes": "",
            }
            (eval_dir / arm / "run-1" / "grading.json").write_text(
                json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8"
            )
            print(f"{data['run_id']}: {passed}/{len(exps)}")
            for e in exps:
                print(f"  [{'OK  ' if e['passed'] else 'FAIL'}] {e['text']}  ({e['evidence']})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
