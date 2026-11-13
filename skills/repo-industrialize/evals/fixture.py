#!/usr/bin/env python3
"""Build the `paygate` eval fixture repository used by evals.json.

Usage: python fixture.py <target-dir> [...]
Each target gets an identical fresh git repo with one commit.
"""
from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

FILES = {
    "src/api.py": '''import json
import urllib.request

CACHE = "/home/yanzhou/.cache/paygate"


def fetch_rate(currency):
    url = "https://rates.example.com/latest?base=" + currency  # 拼接 url
    raw = urllib.request.urlopen(url).read()
    data = json.loads(raw)
    print("fetched", data)
    return data["rate"]


def convert(amount, currency):
    rate = fetch_rate(currency)
    return amount * rate
''',
    "src/legacy_api.py": '''import json
import urllib.request


def fetch_rate_v1(currency):
    raw = urllib.request.urlopen("https://rates.example.com/v1?base=" + currency).read()
    return json.loads(raw)["rate"]
''',
    "tests/test_api.py": '''from src.api import convert


def test_convert(monkeypatch):
    monkeypatch.setattr("src.api.fetch_rate", lambda c: 2.0)
    assert convert(3, "USD") == 6.0
''',
    "README.md": """# paygate

汇率换算小服务。

## 安装

pip install -e .

## 运行测试

pytest -q

部署说明见 [部署](docs/DEPLOY.md)。
""",
    "docs/SETUP.md": """# paygate 安装文档

## 安装

pip install -e .

## 运行测试

python -m pytest

## 目录

- src/api.py 主逻辑
- src/legacy_api.py 旧版接口（仍在用？）
""",
    "AGENTS.md": """# 约定

- 代码里不要写注释。
- 不要用 print 调试，要用 logging。
- 不要硬编码本机绝对路径。
- 改完要跑 pytest。
- 提交信息要说明动机。
""",
    "NOTES.md": """# 过往纠正记录

2026-10-02 我说过 src 下不要写行内注释，你又写了。
2026-10-09 又用 print 调试，说过要用 logging。
2026-10-20 代码里硬编码了 /home/ 开头的路径。
2026-11-01 fetch_rate 没有超时，线上挂过一次，必须带 timeout。
2026-11-05 提交信息只写“修复”，没写为什么。
""",
}


def build(target: Path) -> None:
    if target.exists():
        shutil.rmtree(target)
    for rel, body in FILES.items():
        path = target / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(body, encoding="utf-8")
    shutil.copyfile(target / "docs/SETUP.md", target / "docs/SETUP_old.md")
    subprocess.run(["git", "init", "-q", "."], cwd=target, check=True)
    subprocess.run(["git", "config", "user.email", "eval@local"], cwd=target, check=True)
    subprocess.run(["git", "config", "user.name", "eval"], cwd=target, check=True)
    subprocess.run(["git", "add", "-A"], cwd=target, check=True)
    subprocess.run(["git", "commit", "-qm", "init paygate"], cwd=target, check=True)
    print(f"built {target}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        raise SystemExit(2)
    for argument in sys.argv[1:]:
        build(Path(argument).resolve())
