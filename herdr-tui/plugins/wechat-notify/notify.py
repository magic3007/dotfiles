#!/usr/bin/env python3
"""Send a wechat-reminder notification when a Herdr agent needs attention."""

import fcntl
import json
import os
import subprocess
import sys
import time
from pathlib import Path

PLUGIN_ID = "magic.wechat-notify"
REMINDER_BIN = Path.home() / ".local" / "bin" / "wechat-reminder"
STATE_VERSION = 1
STATE_RETENTION_SECONDS = 7 * 24 * 60 * 60

STATUS_LABELS = {
    "blocked": "等待回答",
    "done": "已完成",
    "idle": "已完成",
}


def env_flag(name, default=True):
    raw = os.environ.get(name)
    if raw is None or not raw.strip():
        return default
    return raw.strip().lower() not in {"0", "false", "no", "off", "disabled"}


def load_env_file(path):
    try:
        content = path.read_text(encoding="utf-8")
    except OSError:
        return
    for raw_line in content.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[len("export ") :].strip()
        key, separator, value = line.partition("=")
        key = key.strip()
        if not key or not separator or key in os.environ:
            continue
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
            value = value[1:-1]
        os.environ[key] = value


def load_env():
    config_dir = os.environ.get("HERDR_PLUGIN_CONFIG_DIR")
    if config_dir:
        load_env_file(Path(config_dir) / ".env")
    load_env_file(Path(__file__).resolve().parent / ".env")


def read_json_env(name):
    raw = os.environ.get(name)
    if not raw:
        return {}
    try:
        value = json.loads(raw)
    except json.JSONDecodeError as error:
        print(f"invalid {name}: {error}", file=sys.stderr)
        return {}
    return value if isinstance(value, dict) else {}


def state_dir():
    raw = os.environ.get("HERDR_PLUGIN_STATE_DIR")
    if raw:
        return Path(raw)
    base = os.environ.get("XDG_STATE_HOME") or str(Path.home() / ".local" / "state")
    return Path(base) / "herdr" / "plugins" / PLUGIN_ID


def read_state(path):
    try:
        state = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {"version": STATE_VERSION, "panes": {}}
    if not isinstance(state, dict) or not isinstance(state.get("panes"), dict):
        return {"version": STATE_VERSION, "panes": {}}
    return state


def write_state(path, state):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    temporary.write_text(json.dumps(state, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    os.replace(temporary, path)


def prune_state(state, now):
    cutoff = now - STATE_RETENTION_SECONDS
    state["panes"] = {
        pane_id: entry
        for pane_id, entry in state["panes"].items()
        if isinstance(entry, dict) and entry.get("updated_at", 0) >= cutoff
    }


def state_key(pane_id):
    socket_path = os.environ.get("HERDR_SOCKET_PATH")
    return f"{socket_path}:{pane_id}" if socket_path else pane_id


def herdr_command(*arguments):
    binary = os.environ.get("HERDR_BIN_PATH") or "herdr"
    try:
        result = subprocess.run(
            [binary, *arguments],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if result.returncode != 0:
        return None
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError:
        return None
    return payload.get("result") if isinstance(payload, dict) else None


def pane_details(pane_id):
    details = {}
    pane_result = herdr_command("pane", "get", pane_id)
    pane = (pane_result or {}).get("pane")
    if not isinstance(pane, dict):
        return details
    details.update(pane)
    tab_id = pane.get("tab_id")
    if tab_id:
        tab_result = herdr_command("tab", "get", tab_id)
        tab = (tab_result or {}).get("tab")
        if isinstance(tab, dict):
            details["tab_label"] = tab.get("label")
    workspace_id = pane.get("workspace_id")
    if workspace_id:
        workspace_result = herdr_command("workspace", "get", workspace_id)
        workspace = (workspace_result or {}).get("workspace")
        if isinstance(workspace, dict):
            details["workspace_label"] = workspace.get("label")
    return details


def agent_entry(pane_id):
    result = herdr_command("agent", "list")
    agents = (result or {}).get("agents")
    if not isinstance(agents, list):
        return {}
    for agent in agents:
        if isinstance(agent, dict) and agent.get("pane_id") == pane_id:
            return agent
    return {}


def last_assistant_reply(session_path):
    path = Path(session_path)
    try:
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return ""
    for raw in reversed(lines):
        try:
            row = json.loads(raw)
        except json.JSONDecodeError:
            continue
        if row.get("type") != "message":
            continue
        message = row.get("message")
        if not isinstance(message, dict) or message.get("role") != "assistant":
            continue
        blocks = message.get("content")
        if not isinstance(blocks, list):
            continue
        text = "\n".join(
            block.get("text", "").strip()
            for block in blocks
            if isinstance(block, dict) and block.get("type") == "text" and block.get("text")
        ).strip()
        if text:
            return text
    return ""


def agent_reply(pane_id):
    agent = agent_entry(pane_id)
    if first_text(agent.get("agent")).lower() != "omp":
        return ""
    session = agent.get("agent_session")
    if not isinstance(session, dict) or session.get("kind") != "path":
        return ""
    return last_assistant_reply(first_text(session.get("value")))


def truncate_reply(reply):
    limit = int(os.environ.get("HERDR_WECHAT_REPLY_CHARS") or 800)
    if limit <= 0 or len(reply) <= limit:
        return reply
    return reply[:limit].rstrip() + "…"


def first_text(*values):
    for value in values:
        if isinstance(value, str) and value.strip():
            return value.strip()
    return ""


def format_location(context, event_data, details):
    workspace = first_text(
        context.get("workspace_label"),
        details.get("workspace_label"),
        event_data.get("workspace_id"),
        context.get("workspace_id"),
        "workspace",
    )
    tab = first_text(context.get("tab_label"), details.get("tab_label"), event_data.get("tab_id"))
    pane = first_text(event_data.get("pane_id"), context.get("pane_id"), "pane")
    return " · ".join(part for part in (workspace, tab, pane) if part)


def format_message(status, context, event_data, details, reply=""):
    agent_kind = first_text(event_data.get("agent"), context.get("focused_pane_agent"))
    display_agent = first_text(event_data.get("display_agent"), agent_kind, "Agent")
    agent = display_agent
    if agent_kind and agent_kind.lower() not in display_agent.lower():
        agent = f"{display_agent} ({agent_kind})"

    status_label = first_text(
        (event_data.get("state_labels") or {}).get(status)
        if isinstance(event_data.get("state_labels"), dict)
        else "",
        STATUS_LABELS.get(status),
        status,
    )
    title = first_text(event_data.get("title"), details.get("terminal_title_stripped"))
    cwd = first_text(details.get("foreground_cwd"), details.get("cwd"), context.get("cwd"))

    lines = [
        f"**Agent**: {agent}",
        f"**位置**: {format_location(context, event_data, details)}",
        f"**状态**: {status_label}（{status}）",
    ]
    if title:
        lines.append(f"**面板标题**: {title}")
    if cwd:
        lines.append(f"**目录**: {cwd}")
    if reply:
        lines.append("**回复**:")
        lines.extend(reply.splitlines())
    lines.append(f"**时间**: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    return "\n".join(lines)


def send_reminder(title, body, color):
    if env_flag("HERDR_WECHAT_DRY_RUN", False):
        print(f"[dry-run] {title}\n{body}")
        return True
    if not REMINDER_BIN.is_file():
        print(f"wechat-reminder not found: {REMINDER_BIN}", file=sys.stderr)
        return False
    try:
        result = subprocess.run(
            [str(REMINDER_BIN), "--title", title, "--desp", body, "--color", color],
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        print(f"wechat-reminder failed: {error}", file=sys.stderr)
        return False
    if result.returncode != 0:
        message = (result.stderr or result.stdout).strip()
        print(f"wechat-reminder exited {result.returncode}: {message}", file=sys.stderr)
        return False
    return True


def send_test_notification():
    title = "Herdr 通知测试"
    body = "\n".join(
        [
            "**来源**: Herdr 插件 magic.wechat-notify",
            f"**主机**: {os.uname().nodename}",
            f"**时间**: {time.strftime('%Y-%m-%d %H:%M:%S')}",
        ]
    )
    return send_reminder(title, body, "blue")


def should_notify(previous_status, status):
    if status == "blocked":
        return env_flag("HERDR_WECHAT_NOTIFY_BLOCKED", True) and previous_status != "blocked"
    if status in {"done", "idle"}:
        if not env_flag("HERDR_WECHAT_NOTIFY_COMPLETION", True):
            return False
        if status == "done":
            return previous_status not in {"done", "idle"}
        return previous_status == "working"
    return False


def handle_event():
    load_env()
    if not env_flag("HERDR_WECHAT_ENABLED", True):
        return 0

    event = read_json_env("HERDR_PLUGIN_EVENT_JSON")
    event_data = event.get("data") if isinstance(event.get("data"), dict) else {}
    event_name = first_text(event.get("event"), os.environ.get("HERDR_PLUGIN_EVENT")).lower()
    status = first_text(event_data.get("agent_status")).lower()
    pane_id = first_text(event_data.get("pane_id"), os.environ.get("HERDR_PANE_ID"))

    if not pane_id:
        return 0

    key = state_key(pane_id)
    directory = state_dir()
    directory.mkdir(parents=True, exist_ok=True)
    state_path = directory / "state.json"
    lock_path = directory / "state.lock"

    if event_name in {"pane_closed", "pane.closed"}:
        with lock_path.open("w", encoding="utf-8") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            state = read_state(state_path)
            if state["panes"].pop(key, None) is not None:
                prune_state(state, int(time.time()))
                write_state(state_path, state)
        return 0

    if not status:
        return 0

    with lock_path.open("w", encoding="utf-8") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        now = int(time.time())
        state = read_state(state_path)
        entries = state["panes"]
        previous = entries.get(key, {}).get("status")
        notify = should_notify(previous, status)
        entries[key] = {"status": status, "updated_at": now}
        prune_state(state, now)
        write_state(state_path, state)

    if not notify:
        return 0
    if not os.environ.get("FEISHU_WEBHOOK_URL") and not os.environ.get("PUSHDEER_KEY"):
        return 0

    context = read_json_env("HERDR_PLUGIN_CONTEXT_JSON")
    details = pane_details(pane_id)
    reply = ""
    if status != "blocked" and env_flag("HERDR_WECHAT_INCLUDE_REPLY", True):
        reply = truncate_reply(agent_reply(pane_id))
    body = format_message(status, context, event_data, details, reply)
    if status == "blocked":
        title = "⚠️ Herdr 需要人工介入"
        color = "orange"
    else:
        title = "✅ Herdr 任务完成"
        color = "green"
    return 0 if send_reminder(title, body, color) else 1


def main():
    if "--test" in sys.argv[1:]:
        load_env()
        return 0 if send_test_notification() else 1
    return handle_event()


if __name__ == "__main__":
    sys.exit(main())
