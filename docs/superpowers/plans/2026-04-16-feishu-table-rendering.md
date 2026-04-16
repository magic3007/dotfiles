# Feishu Table Rendering Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Markdown tables in Claude Code hook notifications render as native Feishu tables, send full messages without truncation, and include session_id.

**Architecture:** Add a Markdown table parser in `wechat-reminder_main.py` that splits message text into text/table segments. Text segments become `lark_md` div elements (existing behavior), table segments become Feishu native `table` card elements. The hook script is simplified to remove truncation and extract `session_id`.

**Tech Stack:** Python 3, Bash, Feishu Interactive Card JSON v2

**Spec:** `docs/superpowers/specs/2026-04-16-feishu-table-rendering-design.md`

**Installation note:** `install.conf.yaml` explicitly copies `wechat-reminder/wechat-reminder` and `wechat-reminder/wechat-reminder_main.py` to `~/.wechat-reminder/`. All new code goes directly into `wechat-reminder_main.py` — no new files, no install changes needed.

---

### Task 1: Modify hook script — extract session_id and remove truncation

**Files:**
- Modify: `claude/hooks/claude-end-reminder.sh`

- [ ] **Step 1: Add session_id extraction alongside last_reply extraction**

In `claude-end-reminder.sh`, after the `LAST_REPLY` extraction block (lines 12-18), add `SESSION_ID` extraction using the same jq/python3 fallback pattern:

```bash
# 从 stdin 提取 Session ID
SESSION_ID=""
if [ -n "$INPUT" ]; then
    if command -v jq &>/dev/null; then
        SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
    else
        SESSION_ID=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('session_id',''))" 2>/dev/null)
    fi
fi
```

**Important:** This reads from `$INPUT` which was already captured at line 6. The `echo "$INPUT" | ...` pattern works because `$INPUT` holds the full stdin content.

- [ ] **Step 2: Add session_id to DESP and remove truncation**

Replace lines 49-61 (from `DESP+=$'\n'"**用户**:` through the end of the Claude reply block) with:

```bash
if [ -n "$SESSION_ID" ]; then
    DESP+=$'\n'"**Session**: ${SESSION_ID}"
fi

DESP+=$'\n'"**用户**: $(whoami)@${HOSTNAME}"
DESP+=$'\n'"**完成时间**: ${TIMESTAMP}"

# 添加 Claude 的最后回复（完整内容，不截断）
if [ -n "$LAST_REPLY" ]; then
    DESP+=$'\n\n'"---"
    DESP+=$'\n'"**Claude 回复**:"
    DESP+=$'\n'"${LAST_REPLY}"
fi
```

This removes the old 500-char truncation logic and inserts `session_id` between the git info and user/timestamp lines.

- [ ] **Step 3: Verify script syntax**

Run:
```bash
bash -n claude/hooks/claude-end-reminder.sh
```
Expected: no output (syntax OK)

- [ ] **Step 4: Commit**

```bash
git add claude/hooks/claude-end-reminder.sh
git commit -m "feat(hook): send full Claude reply and add session_id to Feishu notification"
```

---

### Task 2: Add Markdown table parser and Feishu table builder to wechat-reminder_main.py

**Files:**
- Modify: `wechat-reminder/wechat-reminder_main.py`

- [ ] **Step 1: Write test script for the parser**

Create `wechat-reminder/test_parser.py`. This test imports from `wechat-reminder_main.py` using `importlib` (because the filename contains a hyphen):

```python
#!/usr/bin/env python3
"""Tests for parse_content_segments and build_feishu_table."""
import importlib.util
import os
import json

# Import from hyphenated filename
_dir = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "wrm", os.path.join(_dir, "wechat-reminder_main.py")
)
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)
parse_content_segments = _mod.parse_content_segments
build_feishu_table = _mod.build_feishu_table
table_to_text_fallback = _mod.table_to_text_fallback


def test_plain_text():
    result = parse_content_segments("hello world")
    assert len(result) == 1
    assert result[0]["type"] == "text"
    assert result[0]["content"] == "hello world"
    print("PASS: test_plain_text")


def test_single_table():
    text = """Before table

| Col1 | Col2 |
|------|------|
| a    | b    |
| c    | d    |

After table"""
    result = parse_content_segments(text)
    assert len(result) == 3, f"Expected 3 segments, got {len(result)}: {result}"
    assert result[0]["type"] == "text"
    assert "Before table" in result[0]["content"]
    assert result[1]["type"] == "table"
    assert result[1]["headers"] == ["Col1", "Col2"]
    assert result[1]["rows"] == [["a", "b"], ["c", "d"]]
    assert result[2]["type"] == "text"
    assert "After table" in result[2]["content"]
    print("PASS: test_single_table")


def test_table_with_formatting():
    text = """| 图表 | 文件 | 内容 |
|------|------|------|
| Fig 1 | `fig1.png` | **趋势图** |
| Fig 2 | `fig2.png` | ~~旧图~~ |"""
    result = parse_content_segments(text)
    assert len(result) == 1
    assert result[0]["type"] == "table"
    assert result[0]["headers"] == ["图表", "文件", "内容"]
    assert result[0]["rows"][0] == ["Fig 1", "`fig1.png`", "**趋势图**"]
    assert result[0]["rows"][1] == ["Fig 2", "`fig2.png`", "~~旧图~~"]
    print("PASS: test_table_with_formatting")


def test_truncated_table_no_data_rows():
    text = """| Col1 | Col2 |
|------|------|"""
    result = parse_content_segments(text)
    assert len(result) == 1
    assert result[0]["type"] == "text", f"Expected text (degraded), got {result[0]['type']}"
    print("PASS: test_truncated_table_no_data_rows")


def test_multiple_tables():
    text = """Text 1

| A | B |
|---|---|
| 1 | 2 |

Middle text

| C | D |
|---|---|
| 3 | 4 |

End text"""
    result = parse_content_segments(text)
    assert len(result) == 5
    assert result[0]["type"] == "text"
    assert result[1]["type"] == "table"
    assert result[1]["headers"] == ["A", "B"]
    assert result[2]["type"] == "text"
    assert result[3]["type"] == "table"
    assert result[3]["headers"] == ["C", "D"]
    assert result[4]["type"] == "text"
    print("PASS: test_multiple_tables")


def test_empty_input():
    result = parse_content_segments("")
    assert len(result) == 1
    assert result[0]["type"] == "text"
    assert result[0]["content"] == ""
    print("PASS: test_empty_input")


def test_none_input():
    result = parse_content_segments(None)
    assert len(result) == 1
    assert result[0]["type"] == "text"
    print("PASS: test_none_input")


def test_alignment_markers():
    text = """| Left | Center | Right |
|:-----|:------:|------:|
| a    | b      | c     |"""
    result = parse_content_segments(text)
    assert len(result) == 1
    assert result[0]["type"] == "table"
    assert result[0]["headers"] == ["Left", "Center", "Right"]
    print("PASS: test_alignment_markers")


def test_build_feishu_table():
    segment = {
        "type": "table",
        "headers": ["Name", "Value"],
        "rows": [["a", "1"], ["b", "2"]]
    }
    result = build_feishu_table(segment)
    assert result["tag"] == "table"
    assert len(result["columns"]) == 2
    assert result["columns"][0]["display_name"] == "Name"
    assert result["columns"][0]["data_type"] == "lark_md"
    assert len(result["rows"]) == 2
    assert result["rows"][0] == {"col_0": "a", "col_1": "1"}
    print("PASS: test_build_feishu_table")


def test_table_to_text_fallback():
    segment = {
        "type": "table",
        "headers": ["A", "B"],
        "rows": [["1", "2"]]
    }
    result = table_to_text_fallback(segment)
    assert "| A | B |" in result
    assert "| 1 | 2 |" in result
    print("PASS: test_table_to_text_fallback")


if __name__ == "__main__":
    test_plain_text()
    test_single_table()
    test_table_with_formatting()
    test_truncated_table_no_data_rows()
    test_multiple_tables()
    test_empty_input()
    test_none_input()
    test_alignment_markers()
    test_build_feishu_table()
    test_table_to_text_fallback()
    print("\nAll tests passed!")
```

- [ ] **Step 2: Run tests — verify they fail (functions not defined)**

Run:
```bash
cd wechat-reminder && python3 test_parser.py
```
Expected: `AttributeError: module 'wrm' has no attribute 'parse_content_segments'`

- [ ] **Step 3: Add three new functions to wechat-reminder_main.py**

Add these three functions to `wechat-reminder_main.py` after the existing imports (line 12), before the `PUSHDEER_KEY` line:

```python
import re


def parse_content_segments(text):
    """Split text into alternating text and table segments.

    Returns a list of dicts:
      {"type": "text", "content": "..."}
      {"type": "table", "headers": [...], "rows": [[...], ...]}
    """
    if not text:
        return [{"type": "text", "content": text or ""}]

    lines = text.split('\n')
    segments = []
    current_text_lines = []
    i = 0

    while i < len(lines):
        line = lines[i]

        # Check if this could be a table header row
        if line.strip().startswith('|') and i + 1 < len(lines):
            separator = lines[i + 1].strip()

            # Separator pattern: |---|---| with optional : alignment markers
            if re.match(
                r'^\|[\s:]*-{2,}[\s:]*(\|[\s:]*-{2,}[\s:]*)*\|?\s*$',
                separator
            ):
                # Parse header cells
                headers = [
                    cell.strip()
                    for cell in line.strip().strip('|').split('|')
                ]

                # Move past header + separator
                table_start_line = i
                i += 2

                # Collect data rows
                rows = []
                while i < len(lines) and lines[i].strip().startswith('|'):
                    row_cells = [
                        cell.strip()
                        for cell in lines[i].strip().strip('|').split('|')
                    ]
                    rows.append(row_cells)
                    i += 1

                if rows:
                    # Flush accumulated text
                    if current_text_lines:
                        segments.append({
                            "type": "text",
                            "content": '\n'.join(current_text_lines)
                        })
                        current_text_lines = []

                    segments.append({
                        "type": "table",
                        "headers": headers,
                        "rows": rows
                    })
                else:
                    # No data rows — degrade to plain text
                    current_text_lines.append(lines[table_start_line])
                    current_text_lines.append(lines[table_start_line + 1])

                continue

        current_text_lines.append(line)
        i += 1

    if current_text_lines:
        segments.append({
            "type": "text",
            "content": '\n'.join(current_text_lines)
        })

    return segments


def build_feishu_table(segment):
    """Convert a parsed table segment to a Feishu native table card element."""
    columns = []
    for idx, header in enumerate(segment["headers"]):
        columns.append({
            "name": f"col_{idx}",
            "display_name": header,
            "data_type": "lark_md",
            "width": "auto"
        })

    rows = []
    for row in segment["rows"]:
        row_dict = {}
        for idx, cell in enumerate(row):
            if idx < len(segment["headers"]):
                row_dict[f"col_{idx}"] = cell
        rows.append(row_dict)

    return {
        "tag": "table",
        "page_size": 10,
        "row_height": "low",
        "header_style": {
            "text_align": "left",
            "background_style": "grey",
            "bold": True
        },
        "columns": columns,
        "rows": rows
    }


def table_to_text_fallback(segment):
    """Convert a table segment back to plain text (fallback when >5 tables)."""
    lines = []
    headers = segment["headers"]
    lines.append("| " + " | ".join(headers) + " |")
    lines.append("| " + " | ".join(["---"] * len(headers)) + " |")
    for row in segment["rows"]:
        lines.append("| " + " | ".join(row) + " |")
    return "\n".join(lines)
```

- [ ] **Step 4: Replace the `send_to_feishu` function to use multi-element cards**

Replace the entire `send_to_feishu` function in `wechat-reminder_main.py` with:

```python
def send_to_feishu(webhook_url, title, desp, color="green"):
    """Send message to Feishu via webhook using interactive card.

    Parses desp for Markdown tables and renders them as native Feishu
    table elements. Non-table text is rendered as lark_md divs.
    """
    payload = {
        "msg_type": "interactive",
        "card": {
            "config": {
                "wide_screen_mode": True,
                "enable_forward": True
            },
            "header": {
                "title": {
                    "tag": "plain_text",
                    "content": title
                },
                "template": color
            },
            "elements": []
        }
    }

    if desp:
        segments = parse_content_segments(desp)
        table_count = 0
        for segment in segments:
            if segment["type"] == "text" and segment["content"].strip():
                payload["card"]["elements"].append({
                    "tag": "div",
                    "text": {
                        "tag": "lark_md",
                        "content": segment["content"]
                    }
                })
            elif segment["type"] == "table":
                if table_count < 5:
                    payload["card"]["elements"].append(
                        build_feishu_table(segment)
                    )
                    table_count += 1
                else:
                    payload["card"]["elements"].append({
                        "tag": "div",
                        "text": {
                            "tag": "lark_md",
                            "content": table_to_text_fallback(segment)
                        }
                    })

    try:
        response = requests.post(webhook_url, json=payload, timeout=10)
        response.raise_for_status()
    except Exception as e:
        print(f"Failed to send to Feishu ({webhook_url}): {e}")
```

- [ ] **Step 5: Run tests — verify they pass**

Run:
```bash
cd wechat-reminder && python3 test_parser.py
```
Expected:
```
PASS: test_plain_text
PASS: test_single_table
PASS: test_table_with_formatting
PASS: test_truncated_table_no_data_rows
PASS: test_multiple_tables
PASS: test_empty_input
PASS: test_none_input
PASS: test_alignment_markers
PASS: test_build_feishu_table
PASS: test_table_to_text_fallback

All tests passed!
```

- [ ] **Step 6: Verify Python syntax**

Run:
```bash
python3 -c "import ast; ast.parse(open('wechat-reminder/wechat-reminder_main.py').read()); print('Syntax OK')"
```
Expected: `Syntax OK`

- [ ] **Step 7: Commit**

```bash
git add wechat-reminder/wechat-reminder_main.py wechat-reminder/test_parser.py
git commit -m "feat(wechat-reminder): convert Markdown tables to native Feishu table elements"
```

---

### Task 3: Integration test — send a real test message

**Files:**
- None (manual verification)

- [ ] **Step 1: Reinstall wechat-reminder to pick up changes**

Run:
```bash
cp wechat-reminder/wechat-reminder_main.py $HOME/.wechat-reminder/wechat-reminder_main.py
```

- [ ] **Step 2: Send a test message with a Markdown table**

Run (requires `FEISHU_WEBHOOK_URL` to be set):

```bash
~/.local/bin/wechat-reminder \
  --title "测试: 表格渲染" \
  --desp "**项目**: test-repo
**分支**: main
**Session**: test-session-123
**完成时间**: $(date '+%Y-%m-%d %H:%M:%S')

---
**Claude 回复**:
生成了以下图表：

| 图表 | 文件 | 内容 |
|------|------|------|
| Fig 1 | \`fig1_metrics.png\` | Recall/Precision/F1 三线趋势图 |
| Fig 2 | \`fig2_radar.png\` | 六维雷达图 |
| Fig 3 | \`fig3_heatmap.png\` | 23 篇论文 x 3 迭代的 F1 热力图 |

所有图表已保存到 output/ 目录。" \
  --color blue
```

- [ ] **Step 3: Verify in Feishu**

Open Feishu and check the received card:
1. Table renders as a native Feishu table (not plain text pipes)
2. Table headers are bold with grey background
3. Cells with backtick code (`fig1_metrics.png`) display correctly
4. Text before and after the table displays as normal lark_md
5. Card title, color, and other fields are correct

- [ ] **Step 4: Send a test with no tables (regression check)**

```bash
~/.local/bin/wechat-reminder \
  --title "测试: 纯文本" \
  --desp "**项目**: test-repo
这是一条没有表格的普通消息。
**状态**: 正常" \
  --color green
```

Verify: message renders exactly as before, no regressions.

- [ ] **Step 5: Clean up test file and final commit**

```bash
rm wechat-reminder/test_parser.py
git add wechat-reminder/test_parser.py
git commit -m "chore: remove parser test file after verification"
```
