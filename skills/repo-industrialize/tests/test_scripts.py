import json
import subprocess
import sys
from pathlib import Path

import pytest
import yaml

SKILL = Path(__file__).resolve().parent.parent
CORRECTIONS = SKILL / "scripts" / "corrections.py"
INVENTORY = SKILL / "scripts" / "inventory.py"

sys.path.insert(0, str(SKILL / "scripts"))
import corrections  # noqa: E402


def run(args, cwd):
    return subprocess.run(
        [sys.executable, *args], cwd=cwd, capture_output=True, text=True, timeout=120
    )


def write_ledger(root: Path, entries: list[dict]) -> Path:
    path = root / ".repo-std" / "corrections.yml"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        yaml.safe_dump({"version": 1, "corrections": entries}, allow_unicode=True, sort_keys=False),
        encoding="utf-8",
    )
    return path


def entry(**overrides) -> dict:
    base = {
        "id": "C001",
        "date": "2026-11-13",
        "origin": "对话纠正",
        "rule": "src 下不得出现行内注释",
        "status": "enforced",
        "enforcement": {"kind": "script", "run": "true", "prove": "false"},
    }
    base.update(overrides)
    return base


@pytest.mark.parametrize("kind", ["doc", "review", "convention"])
def test_documentation_is_rejected_as_enforcement(kind):
    problems = corrections.validate_entry(
        entry(enforcement={"kind": kind, "run": "true", "prove": "false"}), "C001"
    )
    assert any("确定性检查" in p for p in problems)


def test_enforced_entry_requires_negative_control():
    problems = corrections.validate_entry(
        entry(enforcement={"kind": "script", "run": "true"}), "C001"
    )
    assert any("prove" in p for p in problems)
    assert not corrections.validate_entry(
        entry(enforcement={"kind": "script", "run": "true", "prove_evidence": "红→绿观测"}), "C001"
    )


def test_waived_entry_requires_reason_hook_and_revisit():
    problems = corrections.validate_entry(
        entry(status="waived", enforcement=None, waiver={"reason": "语义判断"}), "C001"
    )
    assert sum("waiver." in p for p in problems) == 2


def test_stale_waiver_fails_verify(tmp_path):
    write_ledger(tmp_path, [entry(
        status="waived",
        enforcement=None,
        waiver={"reason": "语义判断", "surfaced_in": "PR 模板", "revisit": "2020-01-01"},
    )])
    result = run([str(CORRECTIONS), "--ledger", ".repo-std/corrections.yml", "verify"], tmp_path)
    assert result.returncode == 1
    assert "复查日期" in result.stdout


def test_prove_catches_a_check_that_never_fails(tmp_path):
    write_ledger(tmp_path, [entry(enforcement={"kind": "script", "run": "true", "prove": "true"})])
    result = run([str(CORRECTIONS), "--ledger", ".repo-std/corrections.yml", "prove"], tmp_path)
    assert result.returncode == 1
    assert "退出 0" in result.stdout


def test_run_reports_failing_check(tmp_path):
    write_ledger(tmp_path, [entry(enforcement={"kind": "script", "run": "false", "prove": "false"})])
    result = run([str(CORRECTIONS), "--ledger", ".repo-std/corrections.yml", "run"], tmp_path)
    assert result.returncode == 1
    assert "FAIL" in result.stdout


def test_add_rejects_entry_without_negative_control(tmp_path):
    ledger = write_ledger(tmp_path, [])
    result = run(
        [str(CORRECTIONS), "--ledger", str(ledger), "add", "--rule", "r", "--origin", "o", "--run", "true"],
        tmp_path,
    )
    assert result.returncode == 1
    assert yaml.safe_load(ledger.read_text(encoding="utf-8"))["corrections"] == []


def test_bundled_ledger_template_is_valid():
    data = yaml.safe_load((SKILL / "assets/templates/corrections.yml").read_text(encoding="utf-8"))
    assert corrections.validate(data) == []


def build_repo(root: Path) -> None:
    (root / "src").mkdir(parents=True)
    (root / "docs").mkdir()
    (root / "src/app.py").write_text("def run():\n    return 1\n", encoding="utf-8")
    (root / "src/dead.py").write_text("def gone():\n    return 0\n", encoding="utf-8")
    (root / "docs/setup.md").write_text("# 文档\n\n## 安装\n\npip install -e .\n", encoding="utf-8")
    (root / "docs/setup_copy.md").write_text("# 文档\n\n## 安装\n\npip install -e .\n", encoding="utf-8")
    (root / "README.md").write_text("# demo\n\n见 [部署](docs/deploy.md)，入口 `src/app.py`\n", encoding="utf-8")


def test_inventory_finds_duplicates_orphans_links_and_cjk_headings(tmp_path):
    build_repo(tmp_path)
    out = tmp_path / "report.json"
    result = run([str(INVENTORY), "--root", str(tmp_path), "--out", "-", "--json", str(out)], tmp_path)
    assert result.returncode == 0
    data = json.loads(out.read_text(encoding="utf-8"))
    assert ["docs/setup.md", "docs/setup_copy.md"] in data["duplicates"]
    assert "安装" in data["shared_doc_headings"]
    assert any(item["target"] == "docs/deploy.md" for item in data["broken_links"])
    unreferenced = {r["path"] for r in data["files"] if not r["referenced"]}
    assert "src/dead.py" in unreferenced
    assert "src/app.py" not in unreferenced
    assert "README.md" not in unreferenced
