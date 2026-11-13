#!/usr/bin/env python3
"""检查脚本骨架：复制到 <repo>/.repo-std/checks/ 后改规则与名字。

契约：
    退出码 0 = 通过，非 0 = 发现违规。
    逐行输出 path:line: 说明，让人不读脚本就知道改哪。
    只读、确定性、接受路径参数（同一脚本既扫真实代码，也扫违规样本）。

用法：
    python no_inline_comments.py src
    python no_inline_comments.py .repo-std/checks/fixtures/no_inline_comments   # 必须非 0 退出
"""
from __future__ import annotations

import sys
import tokenize
from pathlib import Path

SKIP_DIRS = {".git", "node_modules", "__pycache__", ".venv", "build", "dist"}


def violations(path: Path) -> list[tuple[int, str]]:
    found = []
    with path.open("rb") as handle:
        for token in tokenize.tokenize(handle.readline):
            if token.type == tokenize.COMMENT and not token.line.lstrip().startswith("#!"):
                found.append((token.start[0], token.string.strip()))
    return found


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    root = Path(argv[1])
    targets = [root] if root.is_file() else sorted(
        p for p in root.rglob("*.py") if not set(p.parts) & SKIP_DIRS
    )
    failures = 0
    for target in targets:
        try:
            hits = violations(target)
        except (OSError, SyntaxError, tokenize.TokenError) as exc:
            print(f"{target}: 无法解析：{exc}", file=sys.stderr)
            return 2
        for line, text in hits:
            failures += 1
            print(f"{target}:{line}: 行内注释：{text}")
    if failures:
        print(f"{failures} 处违规；说明性内容写进 docs/REPO_GUIDE.md，不写进代码行间")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
