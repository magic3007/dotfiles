#!/usr/bin/env python3
"""skill-creator 的 agent CLI 适配层。

上游 skill-creator 把 `claude -p` 写死在评测脚本里。本仓库这份是 omp 专用副本，
所以把"用哪个 CLI 跑探针"抽到这里：

- omp（默认）：`omp -p --mode=json`。事件流里能看到工具调用，能判断 skill 有没有被读。
- claude（回退）：上游原始实现——在 `.claude/commands/` 造一个临时命令，
  用 `claude -p --output-format stream-json` 跑。

为什么非要这层：skill 的"描述会不会被触发"这个指标，只有在**目标 harness** 里测才有意义。
在 omp 里装 skill，就该用 omp 跑触发率；拿 claude 测出来的数字描述的是 Claude Code 的行为。
类比 C++ 的策略模式——调用方只声明"跑一次探针"，具体用哪个 CLI 由这层决定，
上游的 claude 实现原样搬过来当其中一个策略。

CLI 选择顺序：显式参数 > 环境变量 SKILL_CREATOR_CLI > "omp"。
"""

import json
import os
import select
import shutil
import subprocess
import tempfile
import time
import uuid
from pathlib import Path

CLI_CHOICES = ("omp", "claude")
CLI_ENV = "SKILL_CREATOR_CLI"

# 候选 skill 名字里带的随机后缀，用来在工具调用参数里定位"这次探针的 skill"。
# 上游用同样的技巧（clean_name）避免和真实 skill 名混淆。
_SUFFIX_LEN = 8

# 判定"模型确实去看了这个 skill"的工具白名单。
# read 是主流路径；bash/grep/glob 覆盖模型改用命令行读文件的情况。
_TRIGGER_TOOLS = ("read", "bash", "grep", "glob", "find", "jfind")


def resolve_cli(explicit: str | None = None) -> str:
    """决定用哪个 CLI 跑探针。"""
    cli = (explicit or os.environ.get(CLI_ENV) or "omp").strip().lower()
    if cli not in CLI_CHOICES:
        raise ValueError(f"unsupported CLI {cli!r}; expected one of {CLI_CHOICES}")
    return cli


def probe_trigger(
    query: str,
    skill_name: str,
    description: str,
    timeout: int,
    cwd: Path | str,
    model: str | None = None,
    cli: str | None = None,
) -> bool:
    """跑一次探针，返回模型是否去查了这个 skill。

    timeout 到了还没触发就返回 False——触发率是统计量，跑不完的按未触发算。
    """
    cli = resolve_cli(cli)
    if cli == "omp":
        return _probe_omp(query, skill_name, description, timeout, Path(cwd), model)
    return _probe_claude(query, skill_name, description, timeout, Path(cwd), model)


def complete(
    prompt: str,
    model: str | None = None,
    timeout: int = 300,
    cli: str | None = None,
) -> str:
    """一次性把 prompt 丢给 agent，返回纯文本回复。"""
    cli = resolve_cli(cli)
    if cli == "omp":
        return _complete_omp(prompt, model, timeout)
    return _complete_claude(prompt, model, timeout)


# --------------------------------------------------------------------------
# omp 后端
# --------------------------------------------------------------------------


def _write_candidate_skill(cwd: Path, clean_name: str, description: str) -> tuple[Path, bool]:
    """在项目里临时放一个候选 skill，返回 (skill 文件, 是否新建了 .omp/skills 根目录)。

    omp 的项目级 skill 目录是 `<project>/.omp/skills/<name>/SKILL.md`
    （见 omp 源码 discovery/builtin.ts：`PATHS.projectDir` + "skills"），
    所以这里造一个只有 frontmatter 的空壳 skill，让被测的 description
    真正出现在 omp 的 skills 列表里。

    等价于上游在 `.claude/commands/` 下造一个临时命令文件，只是载体不同。
    """
    skills_root = cwd / ".omp" / "skills"
    created_root = not skills_root.exists()
    skill_dir = skills_root / clean_name
    skill_dir.mkdir(parents=True, exist_ok=True)

    # 用 YAML 块标量写 description，避免描述里的冒号/引号破坏 frontmatter 解析。
    indented = "\n  ".join(description.split("\n"))
    body = (
        f"---\n"
        f"name: {clean_name}\n"
        f"description: |\n"
        f"  {indented}\n"
        f"---\n\n"
        f"# {clean_name}\n\n"
        f"This skill handles: {description}\n"
    )
    (skill_dir / "SKILL.md").write_text(body)
    return skill_dir / "SKILL.md", created_root


def _probe_omp(
    query: str,
    skill_name: str,
    description: str,
    timeout: int,
    cwd: Path,
    model: str | None,
) -> bool:
    clean_name = f"{skill_name}-skill-{uuid.uuid4().hex[:_SUFFIX_LEN]}"
    skill_file, created_root = _write_candidate_skill(cwd, clean_name, description)

    cmd = ["omp", "-p", query, "--mode=json", "--no-session"]
    if model:
        cmd.extend(["--model", model])

    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        cwd=str(cwd),
    )
    buffer = b""
    triggered = False
    deadline = time.time() + timeout
    try:
        while True:
            remaining = deadline - time.time()
            if remaining <= 0:
                break
            ready, _, _ = select.select([proc.stdout], [], [], min(0.5, remaining))
            if not ready:
                if proc.poll() is not None:
                    # 子进程已退出，把管道里剩下的读干再收工。
                    buffer += proc.stdout.read() or b""
                    break
                continue
            chunk = os.read(proc.stdout.fileno(), 8192)
            if not chunk:
                break
            buffer += chunk
            while b"\n" in buffer:
                line, buffer = buffer.split(b"\n", 1)
                if _omp_line_triggers(line, clean_name):
                    triggered = True
                    break
            if triggered:
                break
    finally:
        if proc.poll() is None:
            proc.kill()
            proc.wait()
        # 清理临时 skill。目录是我们建的才删，免得误删用户自己的 .omp/skills。
        shutil.rmtree(skill_file.parent, ignore_errors=True)
        if created_root:
            shutil.rmtree(skill_file.parent.parent, ignore_errors=True)
    return triggered


def _omp_line_triggers(line: bytes, clean_name: str) -> bool:
    """判断一行 omp JSON 事件里有没有"去查候选 skill"的工具调用。"""
    try:
        event = json.loads(line)
    except (json.JSONDecodeError, UnicodeDecodeError):
        return False

    candidates: list[tuple[str, dict]] = []

    # 流式事件：toolcall_end 带完整参数，比 message_end 更早到，能早退。
    stream_event = event.get("assistantMessageEvent") or {}
    if stream_event.get("type") == "toolcall_end":
        tool_call = stream_event.get("toolCall") or {}
        candidates.append((tool_call.get("name", ""), tool_call.get("arguments") or {}))

    # 收尾事件：assistant 消息的 content 里也带 toolCall 块。
    if event.get("type") == "message_end":
        message = event.get("message") or {}
        if message.get("role") == "assistant":
            for item in message.get("content") or []:
                if item.get("type") == "toolCall":
                    candidates.append((item.get("name", ""), item.get("arguments") or {}))

    for name, args in candidates:
        if name in _TRIGGER_TOOLS and clean_name in json.dumps(args):
            return True
    return False


def _complete_omp(prompt: str, model: str | None, timeout: int) -> str:
    """用 omp 做一次性补全，返回最后一条 assistant 文本。

    prompt 走临时文件而不是 argv：argv 单参数上限约 128KB，而 improve_description
    的 prompt 里塞了完整 SKILL.md 正文，很容易顶到上限。omp 的 `@file` 前缀能读文件。
    """
    with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False, encoding="utf-8") as handle:
        handle.write(prompt)
        prompt_path = handle.name
    try:
        cmd = ["omp", "-p", f"@{prompt_path}", "--mode=json", "--no-session"]
        if model:
            cmd.extend(["--model", model])
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        if result.returncode != 0:
            raise RuntimeError(
                f"omp -p exited {result.returncode}\nstderr: {result.stderr[-2000:]}"
            )
        return _last_assistant_text(result.stdout)
    finally:
        os.unlink(prompt_path)


def _last_assistant_text(stdout: str) -> str:
    """从 omp 的 JSONL 事件里取最后一条 assistant 文本。"""
    chunks: list[str] = []
    for line in stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if event.get("type") != "message_end":
            continue
        message = event.get("message") or {}
        if message.get("role") != "assistant":
            continue
        text = "".join(
            item.get("text", "")
            for item in message.get("content") or []
            if item.get("type") == "text"
        )
        if text:
            chunks.append(text)
    return chunks[-1] if chunks else ""


# --------------------------------------------------------------------------
# claude 后端（上游原始实现，保留作回退）
# --------------------------------------------------------------------------


def _probe_claude(
    query: str,
    skill_name: str,
    description: str,
    timeout: int,
    cwd: Path,
    model: str | None,
) -> bool:
    unique_id = uuid.uuid4().hex[:_SUFFIX_LEN]
    clean_name = f"{skill_name}-skill-{unique_id}"
    commands_dir = cwd / ".claude" / "commands"
    command_file = commands_dir / f"{clean_name}.md"

    try:
        commands_dir.mkdir(parents=True, exist_ok=True)
        indented_desc = "\n  ".join(description.split("\n"))
        command_file.write_text(
            f"---\n"
            f"description: |\n"
            f"  {indented_desc}\n"
            f"---\n\n"
            f"# {skill_name}\n\n"
            f"This skill handles: {description}\n"
        )

        cmd = [
            "claude",
            "-p", query,
            "--output-format", "stream-json",
            "--verbose",
            "--include-partial-messages",
        ]
        if model:
            cmd.extend(["--model", model])

        env = {k: v for k, v in os.environ.items() if k != "CLAUDECODE"}
        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            cwd=str(cwd),
            env=env,
        )

        triggered = False
        start_time = time.time()
        buffer = ""
        pending_tool_name = None
        accumulated_json = ""
        try:
            while time.time() - start_time < timeout:
                if proc.poll() is not None:
                    remaining = proc.stdout.read()
                    if remaining:
                        buffer += remaining.decode("utf-8", errors="replace")
                    break

                ready, _, _ = select.select([proc.stdout], [], [], 1.0)
                if not ready:
                    continue

                chunk = os.read(proc.stdout.fileno(), 8192)
                if not chunk:
                    break
                buffer += chunk.decode("utf-8", errors="replace")

                while "\n" in buffer:
                    line, buffer = buffer.split("\n", 1)
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        event = json.loads(line)
                    except json.JSONDecodeError:
                        continue

                    if event.get("type") == "stream_event":
                        se = event.get("event", {})
                        se_type = se.get("type", "")
                        if se_type == "content_block_start":
                            cb = se.get("content_block", {})
                            if cb.get("type") == "tool_use":
                                tool_name = cb.get("name", "")
                                if tool_name in ("Skill", "Read"):
                                    pending_tool_name = tool_name
                                    accumulated_json = ""
                                else:
                                    return False
                        elif se_type == "content_block_delta" and pending_tool_name:
                            delta = se.get("delta", {})
                            if delta.get("type") == "input_json_delta":
                                accumulated_json += delta.get("partial_json", "")
                                if clean_name in accumulated_json:
                                    return True
                        elif se_type in ("content_block_stop", "message_stop"):
                            if pending_tool_name:
                                return clean_name in accumulated_json
                            if se_type == "message_stop":
                                return False
                    elif event.get("type") == "assistant":
                        message = event.get("message", {})
                        for content_item in message.get("content", []):
                            if content_item.get("type") != "tool_use":
                                continue
                            tool_name = content_item.get("name", "")
                            tool_input = content_item.get("input", {})
                            if tool_name == "Skill" and clean_name in tool_input.get("skill", ""):
                                triggered = True
                            elif tool_name == "Read" and clean_name in tool_input.get("file_path", ""):
                                triggered = True
                            return triggered
                    elif event.get("type") == "result":
                        return triggered
        finally:
            if proc.poll() is None:
                proc.kill()
                proc.wait()
        return triggered
    finally:
        if command_file.exists():
            command_file.unlink()


def _complete_claude(prompt: str, model: str | None, timeout: int) -> str:
    cmd = ["claude", "-p", "--output-format", "text"]
    if model:
        cmd.extend(["--model", model])
    env = {k: v for k, v in os.environ.items() if k != "CLAUDECODE"}
    result = subprocess.run(
        cmd,
        input=prompt,
        capture_output=True,
        text=True,
        env=env,
        timeout=timeout,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"claude -p exited {result.returncode}\nstderr: {result.stderr[-2000:]}"
        )
    return result.stdout
