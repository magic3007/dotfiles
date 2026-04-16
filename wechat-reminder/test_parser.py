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
