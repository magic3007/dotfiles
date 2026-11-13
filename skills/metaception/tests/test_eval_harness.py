#!/usr/bin/env python3
"""eval harness 回归测试：锁住两条踩过的坑。

T1 表格解析口径：grade_runs.py 的 rows() 必须只吃段内第一个表格，和
    validate_skill.py 的 parse_md_table 一致。两者口径分叉时，`## Checks` 里
    「无法自动化」那张表的表头会被当成第一张表的数据行，负控列读出空值，
    于是校验器 PASS 而评分器 FAIL——假失败比漏判更费时间，因为它看起来像真缺陷。

T2 delta 符号：benchmark.json 的 delta 必须等于 with_skill 减 old_skill。
    aggregate_benchmark.py 按 run_summary 的键序取前两个 config 相减，
    而 old_skill 字典序在前，直接用它的输出会把 +0.89 显示成 -0.89。

跑法：python3 tests/test_eval_harness.py    退出码 0 = 全过
"""
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent


def load(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


grade = load("grade_runs", HERE / "grade_runs.py")
validate = load("validate_skill", HERE.parent / "scripts" / "validate_skill.py")

TWO_TABLES = """
| # | 纠正 | 形态 | 接线位置 | 检查命令 | 通过判据 | 负控 | 记录日期 |
|---|---|---|---|---|---|---|---|
| X1 | 甲 | lint | a.sh | bash a.sh | exit=0 | 还原后 exit=1 | 2026-11-13 |

**无法自动化的纠正**：

| # | 纠正 | 为何 L1–L7 都不可行 | 退而求其次 | 复审触发 |
|---|---|---|---|---|
| X2 | 乙 | 判据是审美 | 写进 Procedure | 出现工具时重评 |
"""


def test_rows_takes_only_first_table() -> None:
    header, rows = grade.rows(TWO_TABLES)
    assert header[1] == "纠正", header
    assert len(rows) == 1, f"应只解析第一张表，实际 {len(rows)} 行: {rows}"
    assert rows[0][0] == "X1", rows[0]


def test_rows_matches_validator_parser() -> None:
    _, mine = grade.rows(TWO_TABLES)
    _, theirs = validate.parse_md_table(TWO_TABLES)
    assert mine == theirs, f"口径分叉:\n grade={mine}\n validator={theirs}"


def test_delta_sign_is_with_minus_old() -> None:
    summary = {
        "with_skill": {"pass_rate": {"mean": 1.0}, "time_seconds": {"mean": 858.0}, "tokens": {"mean": 0}},
        "old_skill": {"pass_rate": {"mean": 0.108}, "time_seconds": {"mean": 452.0}, "tokens": {"mean": 0}},
    }
    delta = grade.compute_delta(summary)
    assert delta["pass_rate"] == "+0.89", delta
    assert delta["time_seconds"] == "+406.0", delta


def test_delta_sign_survives_key_reordering() -> None:
    """aggregate_benchmark.py 按键序取前两个 config，所以键序不能决定符号。"""
    base = {"pass_rate": {"mean": 1.0}, "time_seconds": {"mean": 858.0}, "tokens": {"mean": 0}}
    old = {"pass_rate": {"mean": 0.108}, "time_seconds": {"mean": 452.0}, "tokens": {"mean": 0}}
    a = grade.compute_delta({"with_skill": base, "old_skill": old})
    b = grade.compute_delta({"old_skill": old, "with_skill": base})
    assert a == b, f"键序改变了符号: {a} vs {b}"


def main() -> int:
    tests = [v for k, v in sorted(globals().items()) if k.startswith("test_")]
    failed = 0
    for t in tests:
        try:
            t()
            print(f"[OK  ] {t.__name__}")
        except AssertionError as e:
            failed += 1
            print(f"[FAIL] {t.__name__}: {e}")
    print(f"-- {len(tests) - failed}/{len(tests)} passed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
