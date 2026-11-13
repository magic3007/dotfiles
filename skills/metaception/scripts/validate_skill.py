#!/usr/bin/env python3
"""结构校验器（metaception）。

用途
----
校验一份"抽取出来的产出"是否把纠正与知识都落到了位：

    事实性知识 -> ## Facts        每行带证据 + 复核命令 + 生效条件 + 记录日期
    概念性知识 -> ## Model        机制链 + 分类树 + 判别标准 + 边界
    可执行化   -> ## Checks       每条纠正对应一条检查：形态 + 接线位置 + 命令 + 判据 + 负控
    程序性知识 -> ## Procedure    决策表 + 每步期望输出 + 回滚 + 停止条件
    元认知知识 -> ## Calibration  逐条置信度 + 证伪条件 + 未知清单 + 复审日期

外加两个横切门：检索面（description 与 Facts 的报错串一致性）与卫生（无凭据/内网地址）。

可执行化门的存在理由：把纠正写成散文规则，依赖未来读者的注意力；写成检查则无条件执行。
负控列是硬要求——一条从没见过失败的检查，可能因为路径/glob 写错而永远 PASS，
这比没有检查更糟，因为它提供虚假安全感。

设计思路
--------
把"知识分类"这种主观判断变成可机器判定的检查项，好处是 A/B 对比测试有客观指标：
同一份输入，两个技能产出的 SKILL.md，用同一个校验器打分，差异不来自评审者的口味。

代价与边界：校验器只能判定**结构与可复核性**，不能判定内容对错。
内容正确性由对比测试里的"判别/校准"环节（真人或 agent 评审）负责。
这就像 C++ 的 static_assert 能查类型，查不了算法是否正确。

退出码
------
0 = 全部通过；1 = 存在 FAIL；2 = 文件/结构问题（找不到 SKILL.md 等）。
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# 维度定义：dim 名称既用于分组统计，也用于 --json 输出
# ---------------------------------------------------------------------------
DIM_FACTUAL = "factual"          # 事实性知识
DIM_CONCEPTUAL = "conceptual"    # 概念性知识
DIM_EXECUTABLE = "executable"    # 可执行化（纠正 -> 确定性检查）
DIM_PROCEDURAL = "procedural"    # 程序性知识
DIM_METACOG = "metacognitive"    # 元认知知识
DIM_RETRIEVAL = "retrieval"      # 检索面（横切）
DIM_HYGIENE = "hygiene"          # 卫生（横切）

DIM_ORDER = [
    DIM_FACTUAL,
    DIM_CONCEPTUAL,
    DIM_EXECUTABLE,
    DIM_PROCEDURAL,
    DIM_METACOG,
    DIM_RETRIEVAL,
    DIM_HYGIENE,
]

# 章节标题别名。中英文都收，避免"必须用中文标题"这种无谓约束。
SECTION_ALIASES = {
    "facts": ["facts", "事实", "事实性知识"],
    "model": ["model", "模型", "概念", "概念性知识", "mechanism"],
    "checks": ["checks", "check", "检查", "可执行", "确定性检查", "guards", "guardrails"],
    "procedure": ["procedure", "solution", "步骤", "程序", "程序性知识", "procedure / solution"],
    "calibration": ["calibration", "置信", "元认知", "元认知知识", "confidence"],
}

# 每块内部的必需要素：(检查 id, 维度, 描述, 正则列表, 是否必需)
# 正则全部用 re.I | re.S，方便一段里跨行匹配。
SECTION_CHECKS = {
    "model": [
        ("C1", DIM_CONCEPTUAL, "机制链（症状→机制→根因）", [r"机制链|mechanism chain|root cause chain|因果链"], True),
        ("C2", DIM_CONCEPTUAL, "分类树 / 根因分类", [r"分类树|分类|taxonomy|category|categories|根因 [abc1-9]"], True),
        ("C3", DIM_CONCEPTUAL, "判别标准（近似案例区分信号）", [r"判别标准|discriminat|区分信号|如何区分|look-?alike"], True),
        ("C4", DIM_CONCEPTUAL, "适用边界（不适用情形）", [r"边界|boundar|不适用|does not apply|not applicable|out of scope"], True),
    ],
    "procedure": [
        ("P1", DIM_PROCEDURAL, "决策表（入口观测→分支）", [r"决策表|decision table|分支表|入口观测|if .* then|分支\s*b\d"], True),
        ("P2", DIM_PROCEDURAL, "每步期望输出（断言）", [r"期望|expected|应该(看到|输出)|assert"], True),
        ("P3", DIM_PROCEDURAL, "回滚路径", [r"回滚|rollback|revert|撤销|恢复改动"], True),
        ("P4", DIM_PROCEDURAL, "停止条件", [r"停止条件|stop condition|何时放弃|升级为|escalate|放弃这条路"], True),
    ],
    "calibration": [
        ("M1", DIM_METACOG, "逐条置信度标注", [r"置信度|confidence"], True),
        ("M2", DIM_METACOG, "置信度使用受控词表 verified/inferred/assumed", [r"\bverified\b|\binferred\b|\bassumed\b"], True),
        ("M3", DIM_METACOG, "证伪条件", [r"证伪|falsif|失效条件|would invalidate|refut"], True),
        ("M4", DIM_METACOG, "未知清单", [r"未知清单|unknowns?|未验证|not verified|没验证"], True),
        ("M5", DIM_METACOG, "复审日期（绝对日期）", [r"复审|review[_ ]by|next review|有效期"], True),
    ],
}

# Facts 表头必需列：列名正则 -> 是否允许整列为 unknown
FACT_COLUMNS = [
    ("事实", r"事实|fact|claim"),
    ("证据", r"证据|evidence|来源"),
    ("复核命令", r"复核|验证命令|verify|reproduce|check command"),
    ("生效条件", r"生效条件|适用条件|condition|scope|版本"),
    ("记录日期", r"日期|date"),
]

# Checks 表必需列
CHECK_COLUMNS = [
    ("纠正", r"纠正|correction|mistake|错误|issue"),
    ("形态", r"形态|form|kind|type of check|机制"),
    ("接线位置", r"接线|位置|location|wired|where|文件"),
    ("检查命令", r"命令|command|how to run"),
    ("通过判据", r"判据|通过|pass|expected"),
    ("负控", r"负控|negative|反向验证|故意"),
]

# 形态受控词表：从强到弱。越靠前，越不依赖人的注意力。
FORM_VOCAB = [
    "eliminate",
    "type",
    "test",
    "lint",
    "hook",
    "ci",
    "runtime-assert",
    "command",
]
# 选了这些弱形态，必须解释为什么更强的形态不可行。
WEAK_FORMS = {"runtime-assert", "command"}

# 负控列里的空话：写了等于没写。
EMPTY_EVIDENCE = re.compile(r"^(missing|todo|tbd|n/?a|待补|待验证|无|没做|-+|—+|\?+)$", re.I)

# "人肉提醒"措辞。出现它们，说明一条本该自动化的纠正被写成了散文。
REMINDER_PATTERNS = [
    r"记得(先|要|别|不要)?",
    r"务必",
    r"切记",
    r"不要忘[记了]",
    r"别忘[记了]",
    r"remember to\b",
    r"don'?t forget\b",
    r"be sure to\b",
]

SECRET_PATTERNS = [
    r"(?i)\b(api[_-]?key|secret[_-]?key|access[_-]?token|password|passwd)\b\s*[:=]\s*['\"]?[A-Za-z0-9_\-]{8,}",
    r"sk-[A-Za-z0-9]{16,}",
    r"ghp_[A-Za-z0-9]{20,}",
]
INTERNAL_PATTERNS = [
    r"xaminim\.com",
    r"\b10\.\d{1,3}\.\d{1,3}\.\d{1,3}\b",
    r"\b192\.168\.\d{1,3}\.\d{1,3}\b",
]


class Check:
    __slots__ = ("cid", "dim", "desc", "status", "detail")

    def __init__(self, cid: str, dim: str, desc: str, status: str, detail: str = ""):
        self.cid = cid
        self.dim = dim
        self.desc = desc
        self.status = status  # PASS / FAIL / SKIP
        self.detail = detail

    def as_dict(self) -> dict:
        return {
            "id": self.cid,
            "dim": self.dim,
            "desc": self.desc,
            "status": self.status,
            "detail": self.detail,
        }


# ---------------------------------------------------------------------------
# 解析层
# ---------------------------------------------------------------------------
def split_frontmatter(text: str) -> tuple[dict, str]:
    """切出 YAML frontmatter 与正文。

    这里手写解析而不用 PyYAML：技能文件的 frontmatter 结构固定（name/description/version…），
    引入依赖会让这个脚本在别人的机器上跑不起来。类比 C++ 里为一个小 POD 结构写专用
    反序列化，而不是拖进整个 Boost.Serialization。
    """
    if not text.startswith("---"):
        return {}, text
    end = text.find("\n---", 3)
    if end == -1:
        return {}, text
    raw = text[3:end]
    body = text[end + 4 :]

    meta: dict = {}
    key = None
    block: list[str] = []
    for line in raw.splitlines():
        m = re.match(r"^([A-Za-z_][\w-]*)\s*:\s*(.*)$", line)
        if m:
            if key is not None:
                meta[key] = "\n".join(block).strip() if block else meta.get(key, "")
            key = m.group(1)
            inline = m.group(2).strip()
            block = []
            # `description: |` 是块标量，内容在后续缩进行里
            if inline in ("|", ">", "|-", ">-"):
                meta[key] = ""
            else:
                meta[key] = inline
        elif key is not None:
            block.append(line.strip())
    if key is not None and block:
        meta[key] = "\n".join(block).strip()
    return meta, body


def split_sections(body: str) -> dict:
    """按二级标题切正文，返回 {规范化标题: 内容}。"""
    sections: dict = {}
    current = "_preamble"
    buf: list[str] = []
    for line in body.splitlines():
        m = re.match(r"^##\s+(.+?)\s*$", line)
        if m:
            sections[current] = "\n".join(buf)
            current = m.group(1).strip().lower()
            buf = []
        else:
            buf.append(line)
    sections[current] = "\n".join(buf)
    return sections


def find_section(sections: dict, key: str) -> tuple[str, str]:
    """按别名找章节，返回 (实际标题, 内容)；找不到返回 ("", "")。"""
    for alias in SECTION_ALIASES[key]:
        for title, content in sections.items():
            if alias in title:
                return title, content
    return "", ""


def parse_md_table(text: str) -> tuple[list[str], list[list[str]]]:
    """抽出一段文本里的第一个 Markdown 表格，返回 (表头, 数据行)。"""
    header: list[str] = []
    rows: list[list[str]] = []
    for line in text.splitlines():
        s = line.strip()
        if not s.startswith("|"):
            if header and rows:
                break  # 表格结束
            continue
        cells = [c.strip() for c in s.strip("|").split("|")]
        if not header:
            header = cells
            continue
        # 跳过 |---|---| 分隔行
        if all(re.fullmatch(r":?-{2,}:?", c) for c in cells if c):
            continue
        rows.append(cells)
    return header, rows


# ---------------------------------------------------------------------------
# 检查层
# ---------------------------------------------------------------------------
def check_facts(sections: dict) -> list[Check]:
    out: list[Check] = []
    title, content = find_section(sections, "facts")
    if not content.strip():
        out.append(Check("F0", DIM_FACTUAL, "存在 ## Facts 章节", "FAIL", "未找到事实层章节"))
        for cid, desc in [
            ("F1", "Facts 表含全部 5 列（事实/证据/复核命令/生效条件/日期）"),
            ("F2", "Facts 每行 5 列均非空"),
        ]:
            out.append(Check(cid, DIM_FACTUAL, desc, "FAIL", "无 Facts 表"))
        return out

    out.append(Check("F0", DIM_FACTUAL, "存在 ## Facts 章节", "PASS", f"标题: {title}"))
    header, rows = parse_md_table(content)
    if not header or not rows:
        out.append(Check("F1", DIM_FACTUAL, "Facts 表含全部 5 列", "FAIL", "未解析到 Markdown 表格"))
        out.append(Check("F2", DIM_FACTUAL, "Facts 每行 5 列均非空", "FAIL", "无数据行"))
        return out

    col_idx: dict[str, int] = {}
    for label, pat in FACT_COLUMNS:
        for i, h in enumerate(header):
            if re.search(pat, h, re.I):
                col_idx[label] = i
                break
    missing = [label for label, _ in FACT_COLUMNS if label not in col_idx]
    out.append(
        Check(
            "F1",
            DIM_FACTUAL,
            "Facts 表含全部 5 列（事实/证据/复核命令/生效条件/日期）",
            "FAIL" if missing else "PASS",
            f"缺列: {missing}" if missing else f"{len(header)} 列全齐",
        )
    )

    # 逐行统计"完整行"：5 列都有内容，且证据列不是"经验/印象"这类空话
    vague = re.compile(r"^(经验|印象|凭经验|n/a|na|tbd|-+|无)$", re.I)
    complete = 0
    bad: list[str] = []
    for n, row in enumerate(rows, start=1):
        ok = True
        for label, idx in col_idx.items():
            val = row[idx] if idx < len(row) else ""
            if not val or vague.match(val.strip()):
                ok = False
                break
        if ok:
            complete += 1
        else:
            bad.append(f"row{n}")
    out.append(
        Check(
            "F2",
            DIM_FACTUAL,
            "Facts 每行 5 列均非空且证据非空话",
            "PASS" if complete == len(rows) and rows else "FAIL",
            f"{complete}/{len(rows)} 行完整" + (f"，问题行: {','.join(bad[:5])}" if bad else ""),
        )
    )
    return out


def check_section_keywords(sections: dict, key: str) -> list[Check]:
    out: list[Check] = []
    title, content = find_section(sections, key)
    present = bool(content.strip())
    label = {"model": "## Model", "procedure": "## Procedure", "calibration": "## Calibration"}[key]
    out.append(
        Check(
            f"{key[0].upper()}0",
            SECTION_CHECKS[key][0][1],
            f"存在 {label} 章节",
            "PASS" if present else "FAIL",
            f"标题: {title}" if present else f"未找到 {label}",
        )
    )
    for cid, dim, desc, pats, required in SECTION_CHECKS[key]:
        if not present:
            out.append(Check(cid, dim, desc, "FAIL", "章节缺失"))
            continue
        hit = any(re.search(p, content, re.I | re.S) for p in pats)
        out.append(Check(cid, dim, desc, "PASS" if hit else ("FAIL" if required else "SKIP")))
    # 复审日期额外要求绝对日期格式
    if key == "calibration" and present:
        has_date = bool(re.search(r"\d{4}-\d{2}-\d{2}", content))
        for c in out:
            if c.cid == "M5":
                c.status = "PASS" if has_date else "FAIL"
                c.detail = "" if has_date else "未找到 YYYY-MM-DD 形式的复审日期"
    return out


def check_checks(sections: dict) -> list[Check]:
    """可执行化门：每条纠正都要落成一条带负控的检查。"""
    out: list[Check] = []
    title, content = find_section(sections, "checks")
    if not content.strip():
        out.append(Check("X0", DIM_EXECUTABLE, "存在 ## Checks 章节", "FAIL", "未找到可执行层章节"))
        for cid, desc in [
            ("X1", "Checks 表含全部 6 列（纠正/形态/接线位置/命令/判据/负控）"),
            ("X2", "每条检查的负控为实测失败输出，而非 MISSING/TODO"),
            ("X3", "形态取自受控词表"),
            ("X4", "选用弱形态时写明更强形态为何不可行"),
        ]:
            out.append(Check(cid, DIM_EXECUTABLE, desc, "FAIL", "无 Checks 章节"))
        return out

    out.append(Check("X0", DIM_EXECUTABLE, "存在 ## Checks 章节", "PASS", f"标题: {title}"))

    # 明确声明"本次无纠正项"时，后续各项跳过而不是判负——没有纠正就没有可自动化的东西。
    if re.search(r"本次无纠正项|no corrections this session", content, re.I):
        for cid, desc in [
            ("X1", "Checks 表含全部 6 列"),
            ("X2", "每条检查的负控为实测失败输出"),
            ("X3", "形态取自受控词表"),
            ("X4", "选用弱形态时写明更强形态为何不可行"),
        ]:
            out.append(Check(cid, DIM_EXECUTABLE, desc, "SKIP", "声明本次无纠正项"))
        return out

    header, rows = parse_md_table(content)
    col_idx: dict[str, int] = {}
    for label, pat in CHECK_COLUMNS:
        for i, h in enumerate(header):
            if re.search(pat, h, re.I):
                col_idx[label] = i
                break
    missing = [label for label, _ in CHECK_COLUMNS if label not in col_idx]
    out.append(
        Check(
            "X1",
            DIM_EXECUTABLE,
            "Checks 表含全部 6 列（纠正/形态/接线位置/命令/判据/负控）",
            "FAIL" if missing or not rows else "PASS",
            f"缺列: {missing}" if missing else (f"{len(rows)} 行" if rows else "无数据行"),
        )
    )

    neg_idx = col_idx.get("负控")
    with_neg = 0
    bad_neg: list[str] = []
    for n, row in enumerate(rows, start=1):
        val = row[neg_idx].strip() if neg_idx is not None and neg_idx < len(row) else ""
        if val and not EMPTY_EVIDENCE.match(val):
            with_neg += 1
        else:
            bad_neg.append(f"X{n}")
    out.append(
        Check(
            "X2",
            DIM_EXECUTABLE,
            "每条检查的负控为实测失败输出，而非 MISSING/TODO",
            "PASS" if rows and with_neg == len(rows) else "FAIL",
            f"{with_neg}/{len(rows)} 条有负控" + (f"，缺: {','.join(bad_neg[:5])}" if bad_neg else ""),
        )
    )

    form_idx = col_idx.get("形态")
    forms: list[str] = []
    unknown_forms: list[str] = []
    for row in rows:
        val = row[form_idx].strip().strip("`").lower() if form_idx is not None and form_idx < len(row) else ""
        if val in FORM_VOCAB:
            forms.append(val)
        elif val:
            unknown_forms.append(val)
    out.append(
        Check(
            "X3",
            DIM_EXECUTABLE,
            "形态取自受控词表（eliminate/type/test/lint/hook/ci/runtime-assert/command）",
            "PASS" if rows and not unknown_forms else "FAIL",
            f"表外形态: {unknown_forms[:3]}" if unknown_forms else f"{len(forms)} 条合法",
        )
    )

    # 弱形态需要降级理由：要么本节写了理由，要么在"无法自动化"表里给了判定。
    weak = [f for f in forms if f in WEAK_FORMS]
    has_reason = bool(re.search(r"不可行|无法自动化|为何|理由|why not|degrad|降级", content, re.I))
    out.append(
        Check(
            "X4",
            DIM_EXECUTABLE,
            "选用弱形态（runtime-assert/command）时写明更强形态为何不可行",
            "PASS" if not weak or has_reason else "FAIL",
            f"{len(weak)} 条弱形态" + ("" if not weak or has_reason else "，未见降级理由"),
        )
    )
    return out


def check_no_prose_reminders(sections: dict) -> list[Check]:
    """人肉提醒门：Procedure/Model 里出现"记得/务必"这类措辞，说明纠正该变成检查而没变。"""
    hits: list[str] = []
    for key in ("model", "procedure"):
        _, content = find_section(sections, key)
        if not content:
            continue
        for pat in REMINDER_PATTERNS:
            m = re.search(pat, content, re.I)
            if m:
                hits.append(f"{key}:{m.group(0)}")
    return [
        Check(
            "X5",
            DIM_EXECUTABLE,
            "Model/Procedure 无「记得/务必」类人肉提醒（应改成检查）",
            "FAIL" if hits else "PASS",
            f"命中: {hits[:3]}" if hits else "",
        )
    ]


def check_retrieval(meta: dict, sections: dict) -> list[Check]:
    out: list[Check] = []
    desc = (meta.get("description") or "").strip()
    out.append(
        Check(
            "R1",
            DIM_RETRIEVAL,
            "frontmatter 含 description",
            "PASS" if desc else "FAIL",
            f"{len(desc)} 字符" if desc else "缺失",
        )
    )
    triggers = len(re.findall(r"\([1-9]\)", desc))
    out.append(
        Check(
            "R2",
            DIM_RETRIEVAL,
            "description 含 ≥2 条编号触发条件",
            "PASS" if triggers >= 2 else "FAIL",
            f"{triggers} 条",
        )
    )
    # 报错串一致性：description 里反引号包起来的字面量，至少有一个也出现在 Facts 中。
    # 这一条是"事实性知识支撑检索面"的机器证据，防止 description 写成与事实脱节的口号。
    _, facts = find_section(sections, "facts")
    tokens = [t for t in re.findall(r"`([^`\n]{3,})`", desc) if not t.isspace()]
    shared = [t for t in tokens if t in facts]
    out.append(
        Check(
            "R3",
            DIM_RETRIEVAL,
            "description 的字面量与 Facts 内容一致（报错串对齐）",
            "PASS" if shared else "FAIL",
            f"对齐 {len(shared)}/{len(tokens)}: {shared[:3]}" if tokens else "description 无反引号字面量",
        )
    )
    out.append(
        Check(
            "R4",
            DIM_RETRIEVAL,
            "description 长度 ≤ 800 字符（避免稀释匹配）",
            "PASS" if len(desc) <= 800 else "FAIL",
            f"{len(desc)} 字符",
        )
    )
    return out


def check_hygiene(text: str) -> list[Check]:
    out: list[Check] = []
    secrets = [p for p in SECRET_PATTERNS if re.search(p, text)]
    out.append(
        Check(
            "H1",
            DIM_HYGIENE,
            "无凭据/密钥",
            "FAIL" if secrets else "PASS",
            f"命中 {len(secrets)} 类模式" if secrets else "",
        )
    )
    internal = [p for p in INTERNAL_PATTERNS if re.search(p, text)]
    out.append(
        Check(
            "H2",
            DIM_HYGIENE,
            "无内网地址",
            "FAIL" if internal else "PASS",
            f"命中: {internal}" if internal else "",
        )
    )
    return out


def validate(path: Path) -> dict:
    skill_md = path / "SKILL.md" if path.is_dir() else path
    if not skill_md.is_file():
        return {"file": str(skill_md), "error": "SKILL.md not found", "checks": []}
    text = skill_md.read_text(encoding="utf-8")
    meta, body = split_frontmatter(text)
    sections = split_sections(body)

    checks: list[Check] = []
    checks.append(
        Check(
            "S1",
            DIM_RETRIEVAL,
            "frontmatter 含 kebab-case name",
            "PASS" if re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", meta.get("name", "")) else "FAIL",
            meta.get("name", "<missing>"),
        )
    )
    checks += check_facts(sections)
    for key in ("model", "procedure", "calibration"):
        checks += check_section_keywords(sections, key)
    checks += check_checks(sections)
    checks += check_no_prose_reminders(sections)
    checks += check_retrieval(meta, sections)
    checks += check_hygiene(text)

    per_dim: dict = {}
    for dim in DIM_ORDER:
        dim_checks = [c for c in checks if c.dim == dim]
        passed = sum(1 for c in dim_checks if c.status == "PASS")
        per_dim[dim] = {
            "passed": passed,
            "total": len(dim_checks),
            "ratio": round(passed / len(dim_checks), 3) if dim_checks else 0.0,
        }
    total = len(checks)
    passed = sum(1 for c in checks if c.status == "PASS")
    return {
        "file": str(skill_md),
        "name": meta.get("name", ""),
        "checks": [c.as_dict() for c in checks],
        "per_dim": per_dim,
        "passed": passed,
        "total": total,
        "score": round(passed / total, 3) if total else 0.0,
    }


def main() -> int:
    ap = argparse.ArgumentParser(description="metaception 产出结构校验器")
    ap.add_argument("paths", nargs="+", help="技能目录或 SKILL.md 路径")
    ap.add_argument("--json", action="store_true", help="输出 JSON")
    args = ap.parse_args()

    results = [validate(Path(p)) for p in args.paths]
    if args.json:
        print(json.dumps(results, ensure_ascii=False, indent=2))
    else:
        for r in results:
            print(f"\n=== {r['file']}  name={r.get('name', '')} ===")
            if r.get("error"):
                print(f"  ERROR: {r['error']}")
                continue
            for c in r["checks"]:
                mark = {"PASS": "OK  ", "FAIL": "FAIL", "SKIP": "skip"}[c["status"]]
                extra = f"  ({c['detail']})" if c["detail"] else ""
                print(f"  [{mark}] {c['id']:3} {c['dim']:14} {c['desc']}{extra}")
            dims = "  ".join(
                f"{d}={r['per_dim'][d]['passed']}/{r['per_dim'][d]['total']}" for d in DIM_ORDER
            )
            print(f"  -- {dims}")
            print(f"  -- 总分 {r['passed']}/{r['total']} = {r['score']}")

    if any(r.get("error") for r in results):
        return 2
    return 1 if any(c["status"] == "FAIL" for r in results for c in r["checks"]) else 0


if __name__ == "__main__":
    sys.exit(main())
