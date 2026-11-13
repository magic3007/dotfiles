#!/usr/bin/env python3
"""Deterministic repository census: categories, duplicates, orphans, stale signals.

Usage:
    python inventory.py [--root .] [--out REPORT.md] [--json REPORT.json]
                        [--large-lines 800] [--top 25]

Reads the working tree only. Never writes inside the inspected repository
unless --out/--json point there.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

CATEGORIES = {
    "code": {
        ".py", ".ts", ".tsx", ".js", ".jsx", ".go", ".rs", ".java", ".kt", ".swift",
        ".c", ".h", ".cc", ".cpp", ".hpp", ".cs", ".rb", ".php", ".scala", ".lua",
        ".m", ".mm", ".dart", ".vue", ".svelte", ".sql",
    },
    "script": {".sh", ".bash", ".zsh", ".fish", ".ps1", ".bat", ".mk"},
    "config": {
        ".yml", ".yaml", ".toml", ".ini", ".cfg", ".conf", ".json", ".properties",
        ".env", ".lock", ".gradle", ".tf", ".tfvars",
    },
    "doc": {".md", ".mdx", ".rst", ".adoc", ".txt", ".org"},
    "asset": {
        ".png", ".jpg", ".jpeg", ".gif", ".svg", ".ico", ".webp", ".pdf", ".ttf",
        ".otf", ".woff", ".woff2", ".mp3", ".mp4", ".zip", ".tar", ".gz",
    },
}
EXT_TO_CATEGORY = {ext: cat for cat, exts in CATEGORIES.items() for ext in exts}
NAMED_CONFIG = {
    "Makefile", "Dockerfile", "Justfile", "Procfile", ".gitignore", ".editorconfig",
    ".dockerignore", "LICENSE", "CODEOWNERS",
}
TEXT_MAX_BYTES = 2_000_000
STALE_MARKERS = re.compile(r"\b(TODO|FIXME|XXX|HACK|DEPRECATED|LEGACY|@deprecated)\b")
TOKEN_RE = re.compile(r"[A-Za-z0-9_.\-/]{3,}")
LINK_RE = re.compile(r"\[[^\]]*\]\(([^)\s#]+)[^)]*\)|`([A-Za-z0-9_.-]*/[A-Za-z0-9_./-]+)`")
HEADING_RE = re.compile(r"^#{1,3}\s+(.+?)\s*$", re.MULTILINE)
SKIP_DIRS = {
    ".git", "node_modules", "__pycache__", ".venv", "venv", "dist", "build",
    ".mypy_cache", ".pytest_cache", ".ruff_cache", "target", ".next", ".idea",
}
ENTRY_NAMES = {
    "SKILL.md", "README.md", "AGENTS.md", "CLAUDE.md", "CONTRIBUTING.md", "CHANGELOG.md",
    "LICENSE", "Makefile", "Dockerfile", "Justfile", "package.json", "pyproject.toml",
    "setup.py", "conftest.py", "__init__.py", "__main__.py", "go.mod", "Cargo.toml",
    ".gitignore", ".editorconfig", "CODEOWNERS",
}
ENTRY_PATTERNS = (
    re.compile(r"(^|/)(test_[^/]+|[^/]+_test)\.[A-Za-z]+$"),
    re.compile(r"(^|/)[^/]+\.(test|spec)\.[A-Za-z]+$"),
    re.compile(r"(^|/)(main|index)\.[A-Za-z]+$"),
    re.compile(r"(^|/)\.github/"),
    re.compile(r"(^|/)\.gitlab-ci\.yml$"),
)


def is_entry_point(rel: str) -> bool:
    return Path(rel).name in ENTRY_NAMES or any(p.search(rel) for p in ENTRY_PATTERNS)


def is_fixture(rel: str) -> bool:
    return "fixtures" in Path(rel).parts or "testdata" in Path(rel).parts


def heading_weight(text: str) -> int:
    return sum(2 if ord(ch) > 0x2E80 else 1 for ch in text if not ch.isspace())


def list_files(root: Path) -> list[Path]:
    try:
        out = subprocess.run(
            ["git", "-C", str(root), "ls-files", "--cached", "--others", "--exclude-standard"],
            capture_output=True, text=True, check=True, timeout=60,
        ).stdout
        files = [root / line for line in out.splitlines() if line]
        if files:
            return [f for f in files if f.is_file() and not any(p in SKIP_DIRS for p in f.parts)]
    except (OSError, subprocess.SubprocessError):
        pass
    files = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = sorted(d for d in dirnames if d not in SKIP_DIRS)
        for name in sorted(filenames):
            files.append(Path(dirpath) / name)
    return files


def category_of(path: Path) -> str:
    if path.name in NAMED_CONFIG:
        return "config"
    return EXT_TO_CATEGORY.get(path.suffix.lower(), "other")


def read_text(path: Path) -> str | None:
    try:
        if path.stat().st_size > TEXT_MAX_BYTES:
            return None
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return None


def git_last_commit_days(root: Path, rels: list[str]) -> dict[str, int]:
    ages: dict[str, int] = {}
    try:
        out = subprocess.run(
            ["git", "-C", str(root), "log", "--name-only", "--format=%ct", "--no-merges", "-n", "4000"],
            capture_output=True, text=True, check=True, timeout=120,
        ).stdout
    except (OSError, subprocess.SubprocessError):
        return ages
    import time

    now = time.time()
    wanted = set(rels)
    stamp = 0.0
    for line in out.splitlines():
        if not line:
            continue
        if line.isdigit():
            stamp = float(line)
            continue
        if line in wanted and line not in ages:
            ages[line] = int((now - stamp) // 86400)
    return ages


def collect(root: Path, large_lines: int) -> dict:
    files = list_files(root)
    records: list[dict] = []
    texts: dict[str, str] = {}
    by_hash: dict[str, list[str]] = defaultdict(list)
    for path in files:
        rel = path.relative_to(root).as_posix()
        try:
            size = path.stat().st_size
        except OSError:
            continue
        text = read_text(path)
        lines = text.count("\n") + 1 if text else 0
        record = {
            "path": rel,
            "category": category_of(path),
            "bytes": size,
            "lines": lines,
            "markers": len(STALE_MARKERS.findall(text)) if text else 0,
        }
        records.append(record)
        if text is not None:
            texts[rel] = text
            digest = hashlib.sha256(text.encode("utf-8")).hexdigest()
            by_hash[digest].append(rel)

    interesting: dict[str, set[str]] = defaultdict(set)
    for rel in texts:
        name = Path(rel).name
        interesting[name].add(rel)
        interesting[rel].add(rel)
        stem = Path(rel).stem
        if len(stem) >= 4:
            interesting[stem].add(rel)

    referenced: set[str] = set()
    broken: list[dict] = []
    headings: dict[str, list[str]] = defaultdict(list)
    for rel, text in texts.items():
        for token in set(TOKEN_RE.findall(text)):
            for owner in interesting.get(token, ()):
                if owner != rel:
                    referenced.add(owner)
            if "/" in token:
                tail = token.split("/")[-1]
                for owner in interesting.get(tail, ()):
                    if owner != rel:
                        referenced.add(owner)
        if rel.endswith((".md", ".mdx", ".rst")) and not is_fixture(rel):
            for match in LINK_RE.finditer(text):
                target = match.group(1) or match.group(2)
                if not target or target.startswith(("http://", "https://", "mailto:", "#", "/", "~")):
                    continue
                if "://" in target or target.startswith("<") or "..." in target or "…" in target:
                    continue
                if match.group(2) and not (root / Path(target).parent).is_dir():
                    continue
                candidate = (root / Path(rel).parent / target).resolve()
                if not candidate.exists() and not (root / target.lstrip("/")).exists():
                    broken.append({"source": rel, "target": target})
            for heading in HEADING_RE.findall(text):
                key = heading.strip().lower()
                if heading_weight(key) >= 4:
                    headings[key].append(rel)

    ages = git_last_commit_days(root, [r["path"] for r in records])
    for record in records:
        record["age_days"] = ages.get(record["path"])
        record["referenced"] = (
            record["path"] in referenced
            or is_entry_point(record["path"])
            or is_fixture(record["path"])
        )

    duplicates = [
        sorted(group)
        for group in by_hash.values()
        if len(group) > 1 and not any(is_fixture(p) for p in group)
    ]
    basenames: dict[str, list[str]] = defaultdict(list)
    for record in records:
        basenames[Path(record["path"]).name].append(record["path"])
    forks = {
        name: sorted(paths)
        for name, paths in basenames.items()
        if len(paths) > 1 and EXT_TO_CATEGORY.get(Path(name).suffix.lower()) in {"doc", "config", "code"}
    }
    shared_headings = {
        heading: sorted(set(sources))
        for heading, sources in headings.items()
        if len(set(sources)) > 1
    }
    return {
        "root": str(root),
        "files": records,
        "duplicates": sorted(duplicates),
        "same_basename": dict(sorted(forks.items())),
        "shared_doc_headings": dict(sorted(shared_headings.items())),
        "broken_links": broken,
        "large_files": sorted(
            (r for r in records if r["lines"] >= large_lines),
            key=lambda r: -r["lines"],
        ),
        "large_lines_threshold": large_lines,
    }


def render(data: dict, top: int) -> str:
    records = data["files"]
    by_category: dict[str, dict[str, int]] = defaultdict(lambda: {"files": 0, "lines": 0})
    for record in records:
        bucket = by_category[record["category"]]
        bucket["files"] += 1
        bucket["lines"] += record["lines"]
    lines = [
        "# 仓库盘点报告",
        "",
        f"根目录：`{data['root']}`　文件数：{len(records)}　文本行数：{sum(r['lines'] for r in records)}",
        "",
        "## 1. 分类统计",
        "",
        "| 类别 | 文件数 | 行数 |",
        "| --- | ---: | ---: |",
    ]
    for category in sorted(by_category, key=lambda c: -by_category[c]["files"]):
        bucket = by_category[category]
        lines.append(f"| {category} | {bucket['files']} | {bucket['lines']} |")

    lines += ["", f"## 2. 体量离群（≥ {data['large_lines_threshold']} 行，需结构审查）", ""]
    if data["large_files"]:
        lines += ["| 文件 | 行数 |", "| --- | ---: |"]
        lines += [f"| `{r['path']}` | {r['lines']} |" for r in data["large_files"][:top]]
    else:
        lines.append("无。")

    lines += ["", "## 3. 内容完全重复（同一真相的多份副本）", ""]
    if data["duplicates"]:
        lines += [f"- {' ≡ '.join('`' + p + '`' for p in group)}" for group in data["duplicates"][:top]]
    else:
        lines.append("无。")

    lines += ["", "## 4. 同名不同路径（疑似分叉）", ""]
    if data["same_basename"]:
        lines += [
            f"- `{name}`：{', '.join('`' + p + '`' for p in paths)}"
            for name, paths in list(data["same_basename"].items())[:top]
        ]
    else:
        lines.append("无。")

    lines += ["", "## 5. 文档标题跨文件重复（单一真相源候选）", ""]
    if data["shared_doc_headings"]:
        lines += [
            f"- “{heading}” 出现在：{', '.join('`' + p + '`' for p in sources)}"
            for heading, sources in list(data["shared_doc_headings"].items())[:top]
        ]
    else:
        lines.append("无。")

    lines += ["", "## 6. 悬挂引用（文档指向不存在的路径）", ""]
    if data["broken_links"]:
        lines += [f"- `{item['source']}` → `{item['target']}`" for item in data["broken_links"][:top]]
    else:
        lines.append("无。")

    orphans = [
        r for r in records
        if not r["referenced"] and r["category"] in {"doc", "code", "script", "config"}
    ]
    orphans.sort(key=lambda r: (-(r["age_days"] or 0), r["path"]))
    lines += ["", "## 7. 无人引用（过时候选，必须逐个裁决）", ""]
    if orphans:
        lines += ["| 文件 | 类别 | 行数 | 最后提交距今（天） |", "| --- | --- | ---: | ---: |"]
        lines += [
            f"| `{r['path']}` | {r['category']} | {r['lines']} | {r['age_days'] if r['age_days'] is not None else '—'} |"
            for r in orphans[:top]
        ]
        if len(orphans) > top:
            lines.append(f"| …共 {len(orphans)} 项 | | | |")
    else:
        lines.append("无。")

    marked = sorted((r for r in records if r["markers"]), key=lambda r: -r["markers"])
    lines += ["", "## 8. 陈旧标记（TODO/FIXME/DEPRECATED 等）", ""]
    if marked:
        lines += ["| 文件 | 标记数 |", "| --- | ---: |"]
        lines += [f"| `{r['path']}` | {r['markers']} |" for r in marked[:top]]
    else:
        lines.append("无。")

    lines += ["", "## 9. 下一步", "", "逐项裁决见 references/ssot.md 的三问判据；结论写入清理计划，不留在本报告。", ""]
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".")
    parser.add_argument("--out", default="-")
    parser.add_argument("--json", default=None)
    parser.add_argument("--large-lines", type=int, default=800)
    parser.add_argument("--top", type=int, default=25)
    args = parser.parse_args()

    root = Path(args.root).resolve()
    if not root.is_dir():
        print(f"not a directory: {root}", file=sys.stderr)
        return 2
    data = collect(root, args.large_lines)
    report = render(data, args.top)
    if args.out == "-":
        print(report)
    else:
        out = Path(args.out)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(report, encoding="utf-8")
        print(f"wrote {out}")
    if args.json:
        path = Path(args.json)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"wrote {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
