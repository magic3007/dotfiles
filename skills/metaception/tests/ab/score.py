#!/usr/bin/env python3
"""A/B 打分器：结构分（复用 validate_skill.py）+ 两轮行为分 + 成本。

指标分层与理由
--------------
1) 结构分（26 项机器检查）：回答"产出物是否把四类知识落到位"。
   注意：规则由 B 臂定义，A 臂天然吃亏，所以它**只能证明 B 臂规则被切实执行**，
   不能单独作为"B 更优"的证据。类比：lint 通过率不等于程序正确率。

2) 第一轮行为分（5 题，命中/判别/可复核/校准/边界）：与格式无关，对两臂公平。
   实测出现天花板效应（两臂都满分），因此增设第二轮。

3) 第二轮行为分（4 题，变体迁移/结论过期/第三近似案例/步骤失败）：
   只允许引用技能原文作答，引用会被**逐字校验**。
   - coverage：技能自身覆盖的新问题数（0–4）——这是"B 更优"的主证据。
   - hallucination：声称有依据但引用对不上原文的次数——衡量技能是否诱发编造。
   这一轮不可能天花板：题目刻意落在原始会话之外。
"""

from __future__ import annotations

import importlib.util
import json
import os
import re
import sys
from pathlib import Path

# 校验器位置：从本文件向上找 skills 根（含 scripts/validate_skill.py 的那一层），
# 这样 harness 无论被复制到哪一级目录都能跑起来。
def _find_validator(start: Path) -> Path:
    for base in (start, *start.parents):
        cand = base / "scripts" / "validate_skill.py"
        if cand.is_file():
            return cand
    raise SystemExit(f"validate_skill.py not found upward from {start}")


VALIDATOR = _find_validator(Path(__file__).resolve().parent)
# 数据根目录可用环境变量或第一个命令行参数覆盖，方便把同一套 harness 放到别处复跑。
ROOT = Path(os.environ.get("CQ_AB_ROOT") or (sys.argv[1] if len(sys.argv) > 1 else "/tmp/cq-ab"))
GT = json.loads((ROOT / "ground_truth.json").read_text())

spec = importlib.util.spec_from_file_location("validator", VALIDATOR)
validator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validator)


def sub(root: Path, *names: str) -> Path:
    """在两种目录布局里找子目录：/tmp 跑时是 root/out、root/answers；
    归档进仓库时是 root/results/<case>、root/results/answers。"""
    for name in names:
        cand = root / name
        if cand.is_dir():
            return cand
    return root / names[0]


def skill_file(case_dir: Path) -> Path | None:
    """测试产物文件名是 extracted-skill.md，不是 SKILL.md。

    原因：scripts/sync-skills.py 会把任何含 SKILL.md 的目录当成真技能建视图链接，
    A/B 产物一旦叫 SKILL.md 就会被塞进 ~/.agents/skills 污染所有 harness 的技能列表。
    类比：测试固件不该和产线代码同名，否则打包脚本会把它一起打进去。
    """
    for name in ("extracted-skill.md", "SKILL.md"):
        cand = case_dir / name
        if cand.is_file():
            return cand
    return None


def norm(text: str) -> str:
    """折叠空白后比较：引用时换行/多空格不算编造。"""
    return re.sub(r"\s+", " ", text or "").strip()


def load_json(path: Path) -> dict:
    raw = path.read_text(encoding="utf-8")
    m = re.search(r"\{.*\}", raw, re.S)
    return json.loads(m.group(0)) if m else {}


def kw_hit(text: str, keywords: list[str]) -> int:
    low = (text or "").lower()
    return sum(1 for k in keywords if k.lower() in low)


def score_round1(scenario: str, ans: dict) -> dict:
    gt = GT[scenario]
    out: dict = {}

    q1 = ans.get("q1", {})
    out["B1_hit_usable"] = (
        1.0
        if q1.get("applicable") is True
        and str(q1.get("first_command", "")).strip()
        and str(q1.get("expected_output", "")).strip()
        else 0.0
    )

    q2 = ans.get("q2", {})
    if q2.get("applicable") is gt["q2_applicable"]:
        out["B2_discriminate"] = 1.0 if kw_hit(str(q2.get("reason", "")), gt["q2_keywords"]) else 0.5
    else:
        out["B2_discriminate"] = 0.0

    cmds = [c for c in ans.get("q3", {}).get("commands", []) if str(c).strip()]
    out["B3_reproducible"] = 1.0 if len(cmds) >= 2 else (0.5 if len(cmds) == 1 else 0.0)

    unv = [u for u in ans.get("q4", {}).get("unverified", []) if str(u).strip()]
    out["B4_calibration"] = (
        0.0 if not unv else (1.0 if kw_hit(" ".join(map(str, unv)), gt["q4_keywords"]) else 0.5)
    )

    bounds = ans.get("q5", {}).get("boundaries", [])
    sig = " ".join(
        f"{b.get('signal', '')} {b.get('meaning', '')}" for b in bounds if isinstance(b, dict)
    )
    out["B5_boundary"] = 0.0 if not bounds else (1.0 if kw_hit(sig, gt["q5_keywords"]) else 0.5)

    out["r1_total"] = round(sum(v for k, v in out.items() if k.startswith("B")), 3)
    return out


def score_round2(skill_text: str, ans: dict) -> dict:
    """逐字校验引用，区分"技能真覆盖"与"编造引用"。"""
    hay = norm(skill_text)
    out: dict = {"coverage": 0, "hallucination": 0, "detail": {}}
    for q in ("q6", "q7", "q8", "q9"):
        item = ans.get(q, {}) or {}
        grounded = bool(item.get("grounded_in_skill"))
        quote = norm(str(item.get("quote", "")))
        verified = grounded and len(quote) >= 20 and quote in hay
        if verified:
            out["coverage"] += 1
        elif grounded and quote:
            out["hallucination"] += 1
        out["detail"][q] = {
            "grounded": grounded,
            "quote_verified": verified,
            "quote_len": len(quote),
        }
    return out


def main() -> int:
    rows = []
    for scenario in ("S1", "S2", "S3"):
        for arm in ("A", "B"):
            skill_dir = sub(ROOT, "out", "results") / f"{scenario}-{arm}"
            artifact = skill_file(skill_dir)
            if artifact is None:
                continue
            text = artifact.read_text(encoding="utf-8")
            struct = validator.validate(artifact)
            a1 = sub(ROOT, "answers", "results/answers") / f"{scenario}-{arm}.json"
            a2 = sub(ROOT, "answers2", "results/answers2") / f"{scenario}-{arm}.json"
            row = {
                "case": f"{scenario}-{arm}",
                "arm": arm,
                "struct": f"{struct['passed']}/{struct['total']}",
                "struct_score": struct["score"],
                "per_dim": {d: struct["per_dim"][d]["passed"] for d in validator.DIM_ORDER},
                "bytes": len(text.encode("utf-8")),
                "lines": text.count("\n") + 1,
            }
            row.update(score_round1(scenario, load_json(a1)) if a1.is_file() else {})
            row.update(score_round2(text, load_json(a2)) if a2.is_file() else {})
            rows.append(row)

    print(json.dumps(rows, ensure_ascii=False, indent=2))

    print("\n=== 汇总（3 个用例均值）===")
    hdr = f"{'arm':4} {'结构分':>8} {'命中':>5} {'判别':>5} {'可复核':>6} {'校准':>5} {'边界':>5} {'R1':>5} {'R2覆盖':>7} {'幻觉':>5} {'字节':>7}"
    print(hdr)
    for arm in ("A", "B"):
        arm_rows = [r for r in rows if r["arm"] == arm]
        if not arm_rows:
            continue
        n = len(arm_rows)
        mean = lambda k: sum(r.get(k, 0) for r in arm_rows) / n  # noqa: E731
        print(
            f"{arm:4} {mean('struct_score'):8.3f} {mean('B1_hit_usable'):5.2f} "
            f"{mean('B2_discriminate'):5.2f} {mean('B3_reproducible'):6.2f} "
            f"{mean('B4_calibration'):5.2f} {mean('B5_boundary'):5.2f} "
            f"{mean('r1_total'):5.2f} {mean('coverage'):7.2f} {mean('hallucination'):5.2f} "
            f"{mean('bytes'):7.0f}"
        )

    print("\n=== 第二轮逐题覆盖（1=技能自身给出可逐字验证的依据）===")
    print(f"{'case':8} {'q6变体':>7} {'q7过期':>7} {'q8近似':>7} {'q9步骤':>7}")
    for r in rows:
        d = r.get("detail", {})
        if not d:
            continue
        print(
            f"{r['case']:8} "
            + " ".join(
                f"{('Y' if d.get(q, {}).get('quote_verified') else '.'):>7}"
                for q in ("q6", "q7", "q8", "q9")
            )
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
