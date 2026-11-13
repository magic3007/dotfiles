#!/usr/bin/env python3
"""Grade one eval run: outcomes + whether corrections became catchable checks."""
from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

SKILL = Path(__file__).resolve().parent.parent
CORRECTIONS = SKILL / "scripts" / "corrections.py"
INVENTORY = SKILL / "scripts" / "inventory.py"


def sh(cmd: str, cwd: Path, timeout: int = 300) -> tuple[int, str]:
    try:
        done = subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True, timeout=timeout)
    except subprocess.SubprocessError as exc:
        return 124, str(exc)
    return done.returncode, (done.stdout + done.stderr)[-4000:]


def gate_commands(root: Path) -> list[str]:
    cmds: list[str] = []
    ledger = root / ".repo-std/corrections.yml"
    if ledger.is_file():
        cmds.append(f"python3 {CORRECTIONS} --ledger .repo-std/corrections.yml run")
    makefile = root / "Makefile"
    if makefile.is_file():
        for target in ("check", "lint", "verify", "gate"):
            if re.search(rf"^{target}:", makefile.read_text(encoding="utf-8", errors="ignore"), re.M):
                cmds.append(f"make {target}")
                break
    for candidate in (
        "scripts/check.sh", "check.sh", ".repo-std/gate.sh", "scripts/gate.sh", "scripts/lint.sh",
    ):
        if (root / candidate).is_file():
            cmds.append(f"bash {candidate}")
    for candidate in (
        "scripts/check.py", "check.py", "tools/check.py", "tools/check_conventions.py",
        "scripts/check_conventions.py", ".repo-std/check.py",
    ):
        if (root / candidate).is_file():
            cmds.append(f"python3 {candidate}")
    if not ledger.is_file():
        for candidate in sorted(root.glob(".repo-std/checks/*.py")) + sorted(root.glob("scripts/checks/*.py")):
            cmds.append(f"python3 {candidate.relative_to(root)} src")
    if (root / "pyproject.toml").is_file() and shutil.which("ruff"):
        text = (root / "pyproject.toml").read_text(encoding="utf-8", errors="ignore")
        if "[tool.ruff" in text:
            cmds.append("ruff check .")
    if (root / "tests").is_dir():
        cmds.append("python3 -m pytest -q")
    return cmds


def run_gate(root: Path, cmds: list[str]) -> tuple[bool, str]:
    for cmd in cmds:
        code, out = sh(cmd, root)
        if code != 0:
            return False, f"{cmd} → exit {code}\n{out[-500:]}"
    return True, ""


VIOLATIONS = {
    "inline_comment": lambda text: text.replace("def convert(", "TAX = 1  # 税率\n\n\ndef convert(", 1),
    "print_debug": lambda text: text.replace("def convert(", 'def _dbg():\n    print("debug")\n\n\ndef convert(', 1),
    "hardcoded_path": lambda text: "HOME_CACHE = \"/home/someone/.cache/x\"\n" + text,
    "missing_timeout": lambda text: re.sub(r",\s*timeout\s*=\s*[^)]+\)", ")", text, count=1),
}


def main(run_dir: str) -> int:
    root = Path(run_dir).resolve()
    result: dict = {"run": root.name, "assertions": []}

    def add(text: str, passed: bool, evidence: object = "") -> None:
        result["assertions"].append({"text": text, "passed": bool(passed), "evidence": str(evidence)[:600]})

    files = {p.relative_to(root).as_posix() for p in root.rglob("*") if p.is_file() and ".git/" not in p.as_posix()}
    api = next((root / f for f in ("src/api.py", "api.py", "src/paygate/api.py") if (root / f).is_file()), None)
    api_text = api.read_text(encoding="utf-8") if api else ""

    add("删除了重复文档副本 docs/SETUP_old.md", "docs/SETUP_old.md" not in files, sorted(f for f in files if "SETUP" in f))
    ledger_text = (root / ".repo-std/corrections.yml").read_text(encoding="utf-8") if (root / ".repo-std/corrections.yml").is_file() else ""
    legacy_handled = "src/legacy_api.py" not in files or "legacy_api" in ledger_text
    add("死代码 src/legacy_api.py 被删除或登记为带复查日期的待裁决项", legacy_handled,
        "deleted" if "src/legacy_api.py" not in files else "ledger entry present" if legacy_handled else "still present, no record")
    readme = (root / "README.md").read_text(encoding="utf-8") if (root / "README.md").is_file() else ""
    broken = "docs/DEPLOY.md" in readme and not (root / "docs/DEPLOY.md").is_file()
    add("README 不再指向不存在的 docs/DEPLOY.md", not broken)
    add("fetch_rate 带上了超时（纠正落到代码）", "timeout" in api_text, api_text[:300])
    add("src 下无行内注释、无 print 调试、无硬编码家目录", not re.search(r"^\s*[^#\n]*\s#\s", api_text, re.M)
        and "print(" not in api_text and "/home/" not in api_text)

    cmds = gate_commands(root)
    add("存在可执行的仓库级检查入口", bool([c for c in cmds if "pytest" not in c]), "; ".join(cmds))
    clean_ok, clean_detail = run_gate(root, cmds)
    add("干净仓库上检查全过", clean_ok, clean_detail)

    caught: dict[str, bool] = {}
    if api and cmds:
        for name, mutate in VIOLATIONS.items():
            with tempfile.TemporaryDirectory() as tmp:
                copy = Path(tmp) / "repo"
                shutil.copytree(root, copy, symlinks=True)
                target = copy / api.relative_to(root)
                before = target.read_text(encoding="utf-8")
                after = mutate(before)
                if after == before:
                    caught[name] = False
                    continue
                target.write_text(after, encoding="utf-8")
                ok, _ = run_gate(copy, cmds)
                caught[name] = not ok
    result["violations_caught"] = caught
    add(
        f"注入违规能被检查抓到（{sum(caught.values())}/{len(VIOLATIONS)}）",
        sum(caught.values()) >= 3,
        json.dumps(caught, ensure_ascii=False),
    )

    guide = [f for f in files if re.search(r"(REPO_GUIDE|GUIDE|CONTRIBUTING|docs/.*\.md)$", f)]
    add("产出了流程/规范文档", bool(guide), ", ".join(sorted(guide)[:8]))
    local_skill = [f for f in files if f.endswith("SKILL.md")]
    add("产出了本地 skill", bool(local_skill), ", ".join(local_skill))

    code, out = sh(f"python3 {INVENTORY} --root . --json /tmp/_inv.json --out -", root)
    dup_headings = 0
    if code == 0 and Path("/tmp/_inv.json").is_file():
        data = json.loads(Path("/tmp/_inv.json").read_text(encoding="utf-8"))
        dup_headings = len(data.get("shared_doc_headings", {}))
        add("文档标题无跨文件重复（单一真相源）", dup_headings == 0, json.dumps(list(data.get("shared_doc_headings", {}))[:5], ensure_ascii=False))
        add("无悬挂引用", not data.get("broken_links"), json.dumps(data.get("broken_links", [])[:5], ensure_ascii=False))

    code, out = sh("git log --oneline | head -20", root)
    result["commits"] = out.strip().splitlines()
    passed = sum(1 for a in result["assertions"] if a["passed"])
    result["score"] = f"{passed}/{len(result['assertions'])}"
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1]))
