#!/usr/bin/env python3
"""Collect, validate, and render private insights from local Codex sessions."""

from __future__ import annotations

import argparse
import collections
import datetime as dt
import html
import json
import math
import os
import re
import statistics
import sys
import tempfile
from pathlib import Path
from typing import Any, Iterable


SCHEMA_VERSION = 1
SCRIPT_VERSION = "1.0.0"
DEFAULT_MAX_SESSIONS = 50
USER_TEXT_LIMIT = 700
ASSISTANT_TEXT_LIMIT = 700

INTERNAL_PREFIXES = (
    "# AGENTS.md instructions for ",
    "<environment_context>",
    "<permissions instructions>",
    "<collaboration_mode>",
    "<skills_instructions>",
    "<skill>",
    "<codex_internal_context",
)

SECRET_PATTERNS = (
    (re.compile(r"-----BEGIN [^-]*PRIVATE KEY-----[\s\S]*?-----END [^-]*PRIVATE KEY-----", re.I), "[REDACTED PRIVATE KEY]"),
    (re.compile(r"\b(?:sk|rk|pk)-(?:proj-)?[A-Za-z0-9_-]{16,}\b"), "[REDACTED API KEY]"),
    (re.compile(r"\b(?:ghp|github_pat|glpat|xox[baprs])-[-A-Za-z0-9_]{16,}\b", re.I), "[REDACTED TOKEN]"),
    (re.compile(r"\bAKIA[0-9A-Z]{16}\b"), "[REDACTED AWS KEY]"),
    (re.compile(r"(?i)\b(Bearer)\s+[A-Za-z0-9._~+/-]{12,}=*"), r"\1 [REDACTED]"),
    (
        re.compile(
            r"(?i)\b([A-Z0-9_]*(?:API[_-]?KEY|TOKEN|SECRET|PASSWORD|PASSWD|PRIVATE[_-]?KEY)[A-Z0-9_]*)"
            r"\s*([:=])\s*([^\s,;]+)"
        ),
        r"\1\2[REDACTED]",
    ),
)

REQUIRED_STRING_PATHS = (
    ("at_a_glance", "whats_working"),
    ("at_a_glance", "whats_hindering"),
    ("at_a_glance", "quick_wins"),
    ("at_a_glance", "ambitious_workflows"),
    ("interaction_style", "narrative"),
    ("interaction_style", "key_pattern"),
    ("what_works", "intro"),
    ("friction_analysis", "intro"),
    ("on_the_horizon", "intro"),
    ("fun_ending", "headline"),
    ("fun_ending", "detail"),
)

COUNT_MAPS = ("goal_categories", "outcomes", "satisfaction", "friction", "success")


def codex_home_from_env() -> Path:
    raw = os.environ.get("CODEX_HOME")
    return Path(raw).expanduser() if raw else Path.home() / ".codex"


def ensure_private_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)
    try:
        path.chmod(0o700)
    except OSError:
        pass


def write_private_text(path: Path, text: str) -> None:
    ensure_private_dir(path.parent)
    fd, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(text)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
        path.chmod(0o600)
    finally:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass


def write_private_json(path: Path, value: Any) -> None:
    write_private_text(path, json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def read_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def parse_timestamp(value: Any) -> dt.datetime | None:
    if not isinstance(value, str) or not value:
        return None
    try:
        parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.timezone.utc)
    return parsed


def iso_timestamp(value: dt.datetime | None) -> str:
    return value.astimezone(dt.timezone.utc).isoformat().replace("+00:00", "Z") if value else ""


def redact(text: str) -> str:
    result = text.replace("\x00", "")
    for pattern, replacement in SECRET_PATTERNS:
        result = pattern.sub(replacement, result)
    return result


def compact(text: str, limit: int) -> str:
    cleaned = redact(text).strip()
    cleaned = re.sub(r"[ \t]+", " ", cleaned)
    cleaned = re.sub(r"\n{3,}", "\n\n", cleaned)
    if len(cleaned) <= limit:
        return cleaned
    return cleaned[: max(0, limit - 1)].rstrip() + "…"


def user_text_from_payload(payload: dict[str, Any]) -> list[tuple[str, bool]]:
    texts: list[tuple[str, bool]] = []
    content = payload.get("content")
    if not isinstance(content, list):
        return texts
    for block in content:
        if not isinstance(block, dict) or block.get("type") not in {"input_text", "text"}:
            continue
        raw = block.get("text")
        if not isinstance(raw, str) or not raw.strip():
            continue
        if raw.startswith('<codex_internal_context source="goal">'):
            match = re.search(r"<objective>\s*(.*?)\s*</objective>", raw, re.S)
            if match:
                texts.append((match.group(1).strip(), True))
            continue
        if raw.lstrip().startswith(INTERNAL_PREFIXES):
            continue
        texts.append((raw.strip(), False))
    return texts


def assistant_text_from_payload(payload: dict[str, Any]) -> str:
    content = payload.get("content")
    if not isinstance(content, list):
        return ""
    pieces = []
    for block in content:
        if isinstance(block, dict) and block.get("type") in {"output_text", "text"}:
            value = block.get("text")
            if isinstance(value, str) and value.strip():
                pieces.append(value.strip())
    return "\n".join(pieces)


def jsonish_text(value: Any) -> str:
    if isinstance(value, str):
        return value
    try:
        return json.dumps(value, ensure_ascii=False)
    except (TypeError, ValueError):
        return str(value)


def count_patch(raw: str) -> tuple[int, int, set[str]]:
    added = 0
    removed = 0
    files: set[str] = set()
    for line in raw.splitlines():
        if line.startswith(("*** Add File: ", "*** Update File: ", "*** Delete File: ")):
            files.add(line.split(": ", 1)[1].strip())
        elif line.startswith("+") and not line.startswith("+++"):
            added += 1
        elif line.startswith("-") and not line.startswith("---"):
            removed += 1
    return added, removed, files


def sample_items(values: list[str], count: int = 6) -> list[str]:
    if len(values) <= count:
        return values
    head = math.ceil(count / 2)
    return values[:head] + values[-(count - head) :]


def parse_session(path: Path) -> tuple[dict[str, Any] | None, list[str]]:
    warnings: list[str] = []
    meta: dict[str, Any] = {}
    is_subagent = False
    model = ""
    start: dt.datetime | None = None
    end: dt.datetime | None = None
    user_messages: list[str] = []
    user_timestamps: list[dt.datetime] = []
    seen_goal_objectives: set[str] = set()
    assistant_messages: list[tuple[str, str]] = []
    assistant_count = 0
    last_assistant_time: dt.datetime | None = None
    response_times: list[float] = []
    tool_counts: collections.Counter[str] = collections.Counter()
    item_counts: collections.Counter[str] = collections.Counter()
    event_command_count = 0
    event_file_change_count = 0
    tool_errors = 0
    files_modified: set[str] = set()
    lines_added = 0
    lines_removed = 0
    git_commits = 0
    git_pushes = 0
    max_input_tokens = 0
    max_output_tokens = 0
    max_reasoning_tokens = 0
    max_total_tokens = 0

    try:
        handle = path.open("r", encoding="utf-8", errors="replace")
    except OSError as exc:
        return None, [f"{path}: {exc}"]

    with handle:
        for line_number, line in enumerate(handle, 1):
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                warnings.append(f"{path}:{line_number}: malformed JSON")
                continue
            if not isinstance(record, dict):
                continue
            timestamp = parse_timestamp(record.get("timestamp"))
            if timestamp:
                start = timestamp if start is None or timestamp < start else start
                end = timestamp if end is None or timestamp > end else end
            record_type = record.get("type")
            payload = record.get("payload")
            if not isinstance(payload, dict):
                continue

            if record_type == "session_meta":
                if not meta:
                    meta = payload
                source = payload.get("source")
                if isinstance(source, dict) and isinstance(source.get("subagent"), dict):
                    is_subagent = True
                declared = parse_timestamp(payload.get("timestamp"))
                if declared:
                    start = declared if start is None or declared < start else start
                continue
            if record_type == "turn_context":
                if isinstance(payload.get("model"), str):
                    model = payload["model"]
                continue

            if record_type == "response_item":
                payload_type = payload.get("type")
                if payload_type == "message" and payload.get("role") == "user":
                    accepted: list[str] = []
                    for text, is_goal in user_text_from_payload(payload):
                        if is_goal:
                            normalized = re.sub(r"\s+", " ", text).strip()
                            if normalized in seen_goal_objectives:
                                continue
                            seen_goal_objectives.add(normalized)
                        accepted.append(text)
                    if accepted:
                        user_messages.append("\n".join(accepted))
                        if timestamp:
                            user_timestamps.append(timestamp)
                            if last_assistant_time:
                                seconds = (timestamp - last_assistant_time).total_seconds()
                                if 2 < seconds < 3600:
                                    response_times.append(seconds)
                    continue
                if payload_type == "message" and payload.get("role") == "assistant":
                    assistant_count += 1
                    text = assistant_text_from_payload(payload)
                    if text:
                        assistant_messages.append((str(payload.get("phase") or ""), text))
                    if timestamp:
                        last_assistant_time = timestamp
                    continue
                if payload_type in {"function_call", "custom_tool_call"}:
                    name = str(payload.get("name") or "unknown")
                    raw = jsonish_text(payload.get("arguments", payload.get("input", "")))
                    nested = re.findall(r"\btools\.([A-Za-z0-9_]+)\s*\(", raw) if name == "exec" else []
                    if nested:
                        tool_counts.update(nested)
                    else:
                        namespace = payload.get("namespace")
                        tool_counts[f"{namespace}__{name}" if namespace else name] += 1
                    added, removed, changed = count_patch(raw)
                    lines_added += added
                    lines_removed += removed
                    files_modified.update(changed)
                    git_commits += len(re.findall(r"(?<![A-Za-z0-9_-])git\s+commit\b", raw))
                    git_pushes += len(re.findall(r"(?<![A-Za-z0-9_-])git\s+push\b", raw))
                    continue
                if payload_type in {"function_call_output", "custom_tool_call_output"}:
                    output = jsonish_text(payload.get("output", ""))
                    codes = re.findall(r'"exit_code"\s*:\s*(-?\d+)', output)
                    tool_errors += sum(1 for code in codes if int(code) != 0)
                    continue

            if record_type != "event_msg":
                continue
            event_type = payload.get("type")
            if event_type == "token_count":
                info = payload.get("info")
                usage = info.get("total_token_usage") if isinstance(info, dict) else None
                if isinstance(usage, dict):
                    max_input_tokens = max(max_input_tokens, int(usage.get("input_tokens") or 0))
                    max_output_tokens = max(max_output_tokens, int(usage.get("output_tokens") or 0))
                    max_reasoning_tokens = max(max_reasoning_tokens, int(usage.get("reasoning_output_tokens") or 0))
                    max_total_tokens = max(max_total_tokens, int(usage.get("total_tokens") or 0))
                continue
            if event_type != "item_completed" or not isinstance(payload.get("item"), dict):
                continue
            item = payload["item"]
            item_type = str(item.get("type") or "unknown")
            item_counts[item_type] += 1
            if item_type == "CommandExecution":
                event_command_count += 1
                if isinstance(item.get("exit_code"), int) and item["exit_code"] != 0:
                    tool_errors += 1
            elif item_type == "FileChange":
                event_file_change_count += 1
                for change in item.get("changes") or []:
                    if isinstance(change, dict) and isinstance(change.get("path"), str):
                        files_modified.add(change["path"])
            elif item_type == "McpToolCall":
                server = item.get("server") or item.get("server_name") or "unknown"
                tool = item.get("tool") or item.get("tool_name") or "unknown"
                tool_counts[f"mcp__{server}__{tool}"] += 1

    if not meta:
        warnings.append(f"{path}: missing session_meta")
        return None, warnings
    if is_subagent:
        return {"is_subagent": True}, warnings
    if event_command_count:
        tool_counts["exec_command"] = event_command_count
    if event_file_change_count:
        tool_counts["apply_patch"] = max(tool_counts.get("apply_patch", 0), event_file_change_count)

    duration_minutes = max(0, round((end - start).total_seconds() / 60)) if start and end else 0
    final_messages = [text for phase, text in assistant_messages if phase in {"final", "final_answer"}]
    if not final_messages and assistant_messages:
        final_messages = [assistant_messages[-1][1]]
    first_message = user_messages[0].strip().lower() if user_messages else ""
    invokes_insights = bool(re.match(r"^(?:use\s+)?\$insights\b", first_message) or re.match(r"^/insights\b", first_message))

    return {
        "session_id": str(meta.get("id") or path.stem),
        "source_path": str(path),
        "start_time": iso_timestamp(start),
        "end_time": iso_timestamp(end),
        "project_path": str(meta.get("cwd") or ""),
        "model": model,
        "originator": str(meta.get("originator") or ""),
        "cli_version": str(meta.get("cli_version") or ""),
        "duration_minutes": duration_minutes,
        "user_message_count": len(user_messages),
        "assistant_message_count": assistant_count,
        "user_messages": [compact(value, USER_TEXT_LIMIT) for value in sample_items(user_messages)],
        "assistant_final_messages": [compact(value, ASSISTANT_TEXT_LIMIT) for value in sample_items(final_messages, 3)],
        "tool_counts": dict(tool_counts.most_common()),
        "item_counts": dict(item_counts.most_common()),
        "git_commits": git_commits,
        "git_pushes": git_pushes,
        "input_tokens": max_input_tokens,
        "output_tokens": max_output_tokens,
        "reasoning_tokens": max_reasoning_tokens,
        "total_tokens": max_total_tokens,
        "tool_errors": tool_errors,
        "lines_added": lines_added,
        "lines_removed": lines_removed,
        "files_modified": len(files_modified),
        "user_response_times_seconds": response_times,
        "message_hours_local": [value.astimezone().hour for value in user_timestamps],
        "uses_subagents": any("spawn_agent" in name for name in tool_counts),
        "uses_mcp": any(name.startswith("mcp") for name in tool_counts),
        "uses_web": any("web" in name.lower() and "view" not in name.lower() for name in tool_counts),
        "invokes_insights": invokes_insights,
    }, warnings


def aggregate_sessions(sessions: list[dict[str, Any]], scanned: int) -> dict[str, Any]:
    tools: collections.Counter[str] = collections.Counter()
    projects: collections.Counter[str] = collections.Counter()
    models: collections.Counter[str] = collections.Counter()
    item_counts: collections.Counter[str] = collections.Counter()
    response_times: list[float] = []
    message_hours: list[int] = []
    starts = [parse_timestamp(session.get("start_time")) for session in sessions]
    starts = [value for value in starts if value]
    for session in sessions:
        tools.update({key: value for key, value in (session.get("tool_counts") or {}).items() if isinstance(value, int)})
        item_counts.update({key: value for key, value in (session.get("item_counts") or {}).items() if isinstance(value, int)})
        if session.get("project_path"):
            projects[session["project_path"]] += 1
        if session.get("model"):
            models[session["model"]] += 1
        response_times.extend(session.get("user_response_times_seconds") or [])
        message_hours.extend(session.get("message_hours_local") or [])
    days = {value.astimezone().date().isoformat() for value in starts}
    return {
        "total_sessions_scanned": scanned,
        "total_sessions": len(sessions),
        "date_range": {
            "start": min(starts).astimezone().date().isoformat() if starts else "",
            "end": max(starts).astimezone().date().isoformat() if starts else "",
        },
        "days_active": len(days),
        "total_user_messages": sum(int(s.get("user_message_count") or 0) for s in sessions),
        "total_assistant_messages": sum(int(s.get("assistant_message_count") or 0) for s in sessions),
        "total_duration_hours": round(sum(int(s.get("duration_minutes") or 0) for s in sessions) / 60, 1),
        "total_input_tokens": sum(int(s.get("input_tokens") or 0) for s in sessions),
        "total_output_tokens": sum(int(s.get("output_tokens") or 0) for s in sessions),
        "total_reasoning_tokens": sum(int(s.get("reasoning_tokens") or 0) for s in sessions),
        "total_tokens": sum(int(s.get("total_tokens") or 0) for s in sessions),
        "tool_counts": dict(tools.most_common()),
        "item_counts": dict(item_counts.most_common()),
        "projects": dict(projects.most_common()),
        "models": dict(models.most_common()),
        "git_commits": sum(int(s.get("git_commits") or 0) for s in sessions),
        "git_pushes": sum(int(s.get("git_pushes") or 0) for s in sessions),
        "tool_errors": sum(int(s.get("tool_errors") or 0) for s in sessions),
        "lines_added": sum(int(s.get("lines_added") or 0) for s in sessions),
        "lines_removed": sum(int(s.get("lines_removed") or 0) for s in sessions),
        "files_modified": sum(int(s.get("files_modified") or 0) for s in sessions),
        "median_user_response_seconds": round(statistics.median(response_times), 1) if response_times else 0,
        "average_user_response_seconds": round(statistics.fmean(response_times), 1) if response_times else 0,
        "sessions_using_subagents": sum(bool(s.get("uses_subagents")) for s in sessions),
        "sessions_using_mcp": sum(bool(s.get("uses_mcp")) for s in sessions),
        "sessions_using_web": sum(bool(s.get("uses_web")) for s in sessions),
        "message_hours_local": message_hours,
    }


def collect(args: argparse.Namespace) -> int:
    codex_home = Path(args.codex_home).expanduser().resolve()
    sessions_root = codex_home / "sessions"
    output_dir = Path(args.output_dir).expanduser().resolve()
    output_path = Path(args.output).expanduser().resolve() if args.output else output_dir / "analysis-input.json"
    if not sessions_root.is_dir():
        raise RuntimeError(f"Codex sessions directory does not exist: {sessions_root}")
    paths = sorted(sessions_root.rglob("*.jsonl"), key=lambda value: value.stat().st_mtime, reverse=True)
    sessions: list[dict[str, Any]] = []
    warnings: list[str] = []
    skipped_subagents = skipped_filters = skipped_short = skipped_self = skipped_duplicates = 0
    cutoff = dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=args.days) if args.days else None
    for path in paths:
        session, parse_warnings = parse_session(path)
        warnings.extend(parse_warnings)
        if not session:
            continue
        if session.get("is_subagent"):
            skipped_subagents += 1
            continue
        started = parse_timestamp(session.get("start_time"))
        if cutoff and (not started or started < cutoff):
            skipped_filters += 1
            continue
        if args.project and args.project.casefold() not in str(session.get("project_path") or "").casefold():
            skipped_filters += 1
            continue
        if session.get("invokes_insights"):
            skipped_self += 1
            continue
        if int(session.get("user_message_count") or 0) < 2 or int(session.get("duration_minutes") or 0) < 1:
            skipped_short += 1
            continue
        sessions.append(session)
    deduplicated: dict[str, dict[str, Any]] = {}
    for session in sessions:
        session_id = str(session.get("session_id") or "")
        previous = deduplicated.get(session_id)
        if previous is None:
            deduplicated[session_id] = session
            continue
        current_rank = (int(session.get("user_message_count") or 0), int(session.get("duration_minutes") or 0))
        previous_rank = (int(previous.get("user_message_count") or 0), int(previous.get("duration_minutes") or 0))
        if current_rank > previous_rank:
            deduplicated[session_id] = session
        skipped_duplicates += 1
    sessions = list(deduplicated.values())
    sessions.sort(key=lambda value: str(value.get("start_time") or ""), reverse=True)
    selected = sessions[: args.max_sessions]
    generated = dt.datetime.now(dt.timezone.utc)
    document = {
        "schema_version": SCHEMA_VERSION,
        "generator": {"name": "codex-insights", "version": SCRIPT_VERSION},
        "generated_at": iso_timestamp(generated),
        "privacy": {
            "local_only": True,
            "raw_transcripts_embedded": False,
            "excerpts_redacted_and_truncated": True,
            "note": "Treat this file as private; excerpts can still contain sensitive project context.",
        },
        "filters": {"days": args.days, "project": args.project, "max_sessions_for_qualitative_analysis": args.max_sessions},
        "collection": {
            "sessions_root": str(sessions_root),
            "output_path": str(output_path),
            "top_level_files_scanned": len(paths) - skipped_subagents,
            "eligible_sessions": len(sessions),
            "sessions_in_qualitative_sample": len(selected),
            "skipped_subagent_sessions": skipped_subagents,
            "skipped_by_filter": skipped_filters,
            "skipped_short_sessions": skipped_short,
            "skipped_insights_invocations": skipped_self,
            "skipped_duplicate_session_branches": skipped_duplicates,
            "malformed_records": len(warnings),
            "warnings": warnings[:100],
        },
        "aggregate": aggregate_sessions(sessions, len(paths) - skipped_subagents),
        "codex_features_reference": [
            {"feature": "Skills", "use": "Reusable workflows under ${CODEX_HOME:-$HOME/.codex}/skills/<name>/SKILL.md, invoked as $name."},
            {"feature": "MCP", "use": "Connect external tools and data sources; inspect `codex mcp --help`."},
            {"feature": "Subagents", "use": "Delegate independent bounded work when parallel analysis materially helps."},
            {"feature": "Headless execution", "use": "Use `codex exec` for scripts, CI, and non-interactive jobs."},
            {"feature": "Plugins", "use": "Bundle Skills and integrations; inspect `codex plugin --help`."},
            {"feature": "Project guidance", "use": "Put recurring repository instructions in AGENTS.md."},
        ],
        "sessions": [
            {
                key: value
                for key, value in session.items()
                if key not in {"source_path", "item_counts", "user_response_times_seconds", "message_hours_local", "invokes_insights"}
            }
            for session in selected
        ],
    }
    write_private_json(output_path, document)
    print(json.dumps({"analysis_input": str(output_path), "eligible_sessions": len(sessions), "qualitative_sample": len(selected), "scanned": len(paths) - skipped_subagents, "warnings": len(warnings)}, ensure_ascii=False))
    return 0


def analysis_skeleton(input_data: dict[str, Any]) -> dict[str, Any]:
    sample_count = int(input_data.get("collection", {}).get("sessions_in_qualitative_sample") or 0)
    return {
        "schema_version": SCHEMA_VERSION,
        "analysis_metadata": {
            "analysis_input": str(input_data.get("collection", {}).get("output_path") or "analysis-input.json"),
            "session_sample_count": sample_count,
            "language": "TODO: use the user's language",
            "evidence_limitations": "TODO: state material limitations or say none beyond sampled and truncated excerpts",
        },
        "at_a_glance": {
            "whats_working": "TODO",
            "whats_hindering": "TODO",
            "quick_wins": "TODO",
            "ambitious_workflows": "TODO",
        },
        "project_areas": {"areas": []},
        "interaction_style": {"narrative": "TODO", "key_pattern": "TODO"},
        "what_works": {"intro": "TODO", "impressive_workflows": []},
        "friction_analysis": {"intro": "TODO", "categories": []},
        "suggestions": {"agents_md_additions": [], "features_to_try": [], "usage_patterns": []},
        "on_the_horizon": {"intro": "TODO", "opportunities": []},
        "fun_ending": {"headline": "TODO", "detail": "TODO"},
        "evidence_summary": {name: {} for name in COUNT_MAPS},
    }


def init_analysis(args: argparse.Namespace) -> int:
    input_path = Path(args.input).expanduser().resolve()
    output_path = Path(args.output).expanduser().resolve()
    write_private_json(output_path, analysis_skeleton(read_json(input_path)))
    print(json.dumps({"analysis": str(output_path), "source": str(input_path)}, ensure_ascii=False))
    return 0


def lookup(value: Any, path: tuple[str, ...]) -> Any:
    current = value
    for key in path:
        if not isinstance(current, dict):
            return None
        current = current.get(key)
    return current


def validate_analysis_data(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, dict):
        return ["analysis root must be a JSON object"]
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"schema_version must be {SCHEMA_VERSION}")
    for path in REQUIRED_STRING_PATHS:
        found = lookup(value, path)
        if not isinstance(found, str) or not found.strip() or "TODO" in found:
            errors.append(f"{'.'.join(path)} must be a non-placeholder string")
    metadata = value.get("analysis_metadata")
    if not isinstance(metadata, dict):
        errors.append("analysis_metadata must be an object")
    else:
        for key in ("language", "evidence_limitations"):
            found = metadata.get(key)
            if not isinstance(found, str) or not found.strip() or "TODO" in found:
                errors.append(f"analysis_metadata.{key} must be a non-placeholder string")
    list_paths = (
        ("project_areas", "areas"),
        ("what_works", "impressive_workflows"),
        ("friction_analysis", "categories"),
        ("suggestions", "agents_md_additions"),
        ("suggestions", "features_to_try"),
        ("suggestions", "usage_patterns"),
        ("on_the_horizon", "opportunities"),
    )
    for path in list_paths:
        if not isinstance(lookup(value, path), list):
            errors.append(f"{'.'.join(path)} must be an array")
    evidence = value.get("evidence_summary")
    if not isinstance(evidence, dict):
        errors.append("evidence_summary must be an object")
    else:
        for name in COUNT_MAPS:
            count_map = evidence.get(name)
            if not isinstance(count_map, dict):
                errors.append(f"evidence_summary.{name} must be an object")
                continue
            for key, count in count_map.items():
                if not isinstance(key, str) or not isinstance(count, int) or isinstance(count, bool) or count < 0:
                    errors.append(f"evidence_summary.{name} values must be non-negative integers")
                    break
    return errors


def validate_analysis(args: argparse.Namespace) -> int:
    path = Path(args.input).expanduser().resolve()
    errors = validate_analysis_data(read_json(path))
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print(json.dumps({"valid": True, "analysis": str(path)}, ensure_ascii=False))
    return 0


def esc(value: Any) -> str:
    return html.escape(str(value if value is not None else ""), quote=True)


def rich_text(value: Any) -> str:
    escaped = esc(value)
    escaped = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", escaped)
    return escaped.replace("\n\n", "</p><p>").replace("\n", "<br>")


def human_number(value: Any) -> str:
    try:
        number = float(value)
    except (TypeError, ValueError):
        return "0"
    if abs(number) >= 1_000_000:
        return f"{number / 1_000_000:.1f}M"
    if abs(number) >= 1_000:
        return f"{number / 1_000:.1f}K"
    return f"{number:g}"


def bar_chart(values: dict[str, Any], color: str = "#2563eb", limit: int = 8) -> str:
    rows = [(str(key), int(value)) for key, value in values.items() if isinstance(value, int) and value > 0]
    rows.sort(key=lambda item: item[1], reverse=True)
    rows = rows[:limit]
    if not rows:
        return '<p class="muted">No data</p>'
    maximum = max(value for _, value in rows)
    parts = []
    for label, value in rows:
        width = max(2, value / maximum * 100)
        parts.append(
            f'<div class="bar-row"><span class="bar-label">{esc(label.replace("_", " "))}</span>'
            f'<span class="bar-track"><span class="bar-fill" style="width:{width:.1f}%;background:{esc(color)}"></span></span>'
            f'<span class="bar-value">{value}</span></div>'
        )
    return "".join(parts)


def cards(items: Iterable[dict[str, Any]], title_key: str, body_key: str) -> str:
    rendered = []
    for item in items:
        if isinstance(item, dict):
            rendered.append(f'<article class="card"><h3>{esc(item.get(title_key, ""))}</h3><p>{rich_text(item.get(body_key, ""))}</p></article>')
    return '<div class="card-grid">' + "".join(rendered) + "</div>" if rendered else '<p class="muted">Insufficient evidence for this section.</p>'


def code_card(title: Any, description: Any, code: Any) -> str:
    code_html = ""
    if code:
        code_html = '<div class="copy-row"><code>' + esc(code) + '</code><button type="button" onclick="copyPrevious(this)">Copy</button></div>'
    return f'<article class="card"><h3>{esc(title)}</h3><p>{rich_text(description)}</p>{code_html}</article>'


def render_html(data: dict[str, Any], insights: dict[str, Any]) -> str:
    aggregate = data.get("aggregate") or {}
    glance = insights.get("at_a_glance") or {}
    areas = (insights.get("project_areas") or {}).get("areas") or []
    works = insights.get("what_works") or {}
    friction = insights.get("friction_analysis") or {}
    suggestions = insights.get("suggestions") or {}
    horizon = insights.get("on_the_horizon") or {}
    interaction = insights.get("interaction_style") or {}
    ending = insights.get("fun_ending") or {}
    evidence = insights.get("evidence_summary") or {}
    metadata = insights.get("analysis_metadata") or {}

    stat_cards = [
        ("Sessions", aggregate.get("total_sessions", 0)),
        ("User messages", aggregate.get("total_user_messages", 0)),
        ("Active days", aggregate.get("days_active", 0)),
        ("Hours", aggregate.get("total_duration_hours", 0)),
        ("Tokens", human_number(aggregate.get("total_tokens", 0))),
        ("Commits", aggregate.get("git_commits", 0)),
    ]
    stats_html = "".join(f'<div class="stat"><strong>{esc(value)}</strong><span>{esc(label)}</span></div>' for label, value in stat_cards)
    glance_html = "".join(
        f'<div class="glance-item"><strong>{esc(label)}</strong><p>{rich_text(glance.get(key, ""))}</p></div>'
        for label, key in (
            ("What is working", "whats_working"),
            ("What is hindering you", "whats_hindering"),
            ("Quick wins", "quick_wins"),
            ("Ambitious workflows", "ambitious_workflows"),
        )
    )
    area_cards = []
    for area in areas:
        if not isinstance(area, dict):
            continue
        count = area.get("session_count")
        badge = f'<span class="badge">~{esc(count)} sessions</span>' if count is not None else ""
        area_cards.append(f'<article class="card"><h3>{esc(area.get("name", ""))}{badge}</h3><p>{rich_text(area.get("description", ""))}</p></article>')
    friction_cards = []
    for item in friction.get("categories") or []:
        if not isinstance(item, dict):
            continue
        examples = item.get("examples") or []
        list_html = "<ul>" + "".join(f"<li>{rich_text(example)}</li>" for example in examples) + "</ul>" if examples else ""
        friction_cards.append(
            f'<article class="card warning"><h3>{esc(item.get("category", ""))}</h3>'
            f'<p>{rich_text(item.get("description", ""))}</p>{list_html}</article>'
        )
    additions_html = "".join(
        code_card(item.get("prompt_scaffold", "AGENTS.md"), item.get("why", ""), item.get("addition", ""))
        for item in suggestions.get("agents_md_additions") or [] if isinstance(item, dict)
    )
    features_html = "".join(
        code_card(item.get("feature", ""), f'{item.get("one_liner", "")} {item.get("why_for_you", "")}'.strip(), item.get("example_code", ""))
        for item in suggestions.get("features_to_try") or [] if isinstance(item, dict)
    )
    patterns_html = "".join(
        code_card(item.get("title", ""), f'{item.get("suggestion", "")} {item.get("detail", "")}'.strip(), item.get("copyable_prompt", ""))
        for item in suggestions.get("usage_patterns") or [] if isinstance(item, dict)
    )
    horizon_html = "".join(
        code_card(item.get("title", ""), f'{item.get("whats_possible", "")} {item.get("how_to_try", "")}'.strip(), item.get("copyable_prompt", ""))
        for item in horizon.get("opportunities") or [] if isinstance(item, dict)
    )

    return f'''<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Codex Insights</title>
  <style>
    :root {{ color-scheme:light; --ink:#172033; --muted:#667085; --line:#e4e7ec; --panel:#fff; --bg:#f5f7fb; --brand:#2563eb; }}
    * {{ box-sizing:border-box; }}
    body {{ margin:0; background:var(--bg); color:var(--ink); font:15px/1.65 ui-sans-serif,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif; }}
    main {{ max-width:980px; margin:0 auto; padding:48px 22px 80px; }}
    h1 {{ font-size:42px; margin:0 0 2px; letter-spacing:-.04em; }} h2 {{ margin:44px 0 14px; font-size:25px; letter-spacing:-.02em; }} h3 {{ font-size:16px; margin:0 0 8px; }} p {{ margin:0 0 10px; }}
    .subtitle,.muted {{ color:var(--muted); }}
    .stats {{ display:grid; grid-template-columns:repeat(6,1fr); gap:10px; margin:24px 0; }}
    .stat,.card,.glance,.chart,.ending {{ background:var(--panel); border:1px solid var(--line); border-radius:14px; box-shadow:0 5px 18px rgba(16,24,40,.035); }}
    .stat {{ padding:14px; text-align:center; }} .stat strong {{ display:block; font-size:21px; }} .stat span {{ color:var(--muted); font-size:12px; }}
    .glance {{ padding:22px; border-top:4px solid var(--brand); }} .glance-item {{ display:grid; grid-template-columns:170px 1fr; gap:16px; padding:12px 0; border-bottom:1px solid var(--line); }} .glance-item:last-child {{ border:0; }} .glance-item p {{ margin:0; }}
    .card-grid,.charts {{ display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:14px; }} .card {{ padding:18px; min-width:0; }} .card.warning {{ border-left:4px solid #d97706; }} .card ul {{ margin:10px 0 0; padding-left:20px; }}
    .badge {{ float:right; color:var(--brand); background:#eff6ff; border-radius:999px; padding:2px 8px; font-size:11px; font-weight:600; }} .key-pattern {{ margin-top:14px; padding:14px 16px; background:#eef4ff; border-radius:10px; }}
    .copy-row {{ display:flex; gap:8px; margin-top:12px; align-items:stretch; }} code {{ display:block; flex:1; white-space:pre-wrap; overflow-wrap:anywhere; background:#101828; color:#f2f4f7; padding:11px; border-radius:8px; font:12px/1.5 ui-monospace,SFMono-Regular,Consolas,monospace; }}
    button {{ border:0; border-radius:8px; background:#e9efff; color:#1949a3; padding:0 12px; cursor:pointer; font-weight:600; }}
    .chart {{ padding:18px; }} .chart h3 {{ margin-bottom:14px; }} .bar-row {{ display:grid; grid-template-columns:135px 1fr 38px; gap:8px; align-items:center; margin:8px 0; font-size:12px; }}
    .bar-label {{ overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }} .bar-track {{ height:8px; border-radius:999px; background:#eef0f4; overflow:hidden; }} .bar-fill {{ display:block; height:100%; border-radius:999px; }} .bar-value {{ text-align:right; color:var(--muted); }}
    .ending {{ margin-top:42px; padding:24px; text-align:center; background:linear-gradient(135deg,#eef4ff,#f5f3ff); }} footer {{ margin-top:40px; color:var(--muted); font-size:12px; border-top:1px solid var(--line); padding-top:18px; }}
    @media (max-width:760px) {{ .stats {{ grid-template-columns:repeat(3,1fr); }} .card-grid,.charts {{ grid-template-columns:1fr; }} .glance-item {{ grid-template-columns:1fr; gap:2px; }} }}
  </style>
</head>
<body><main>
  <h1>Codex Insights</h1>
  <p class="subtitle">{esc(aggregate.get("date_range", {}).get("start", ""))} to {esc(aggregate.get("date_range", {}).get("end", ""))} · generated locally</p>
  <div class="stats">{stats_html}</div>
  <section class="glance">{glance_html}</section>
  <h2>What You Work On</h2><div class="card-grid">{''.join(area_cards) or '<p class="muted">Insufficient evidence.</p>'}</div>
  <h2>How You Use Codex</h2><div class="card"><p>{rich_text(interaction.get("narrative", ""))}</p><div class="key-pattern"><strong>Key pattern:</strong> {rich_text(interaction.get("key_pattern", ""))}</div></div>
  <h2>What Is Working</h2><p class="subtitle">{rich_text(works.get("intro", ""))}</p>{cards(works.get("impressive_workflows") or [], "title", "description")}
  <h2>Where Things Go Wrong</h2><p class="subtitle">{rich_text(friction.get("intro", ""))}</p><div class="card-grid">{''.join(friction_cards) or '<p class="muted">Insufficient evidence.</p>'}</div>
  <h2>Existing Codex Features to Try</h2><div class="card-grid">{additions_html}{features_html}{'<p class="muted">No evidence-based configuration changes recommended.</p>' if not additions_html and not features_html else ''}</div>
  <h2>New Ways to Use Codex</h2><div class="card-grid">{patterns_html or '<p class="muted">Insufficient evidence.</p>'}</div>
  <h2>On the Horizon</h2><p class="subtitle">{rich_text(horizon.get("intro", ""))}</p><div class="card-grid">{horizon_html or '<p class="muted">Insufficient evidence.</p>'}</div>
  <h2>Usage Signals</h2>
  <div class="charts">
    <div class="chart"><h3>Top tools</h3>{bar_chart(aggregate.get("tool_counts") or {}, "#2563eb")}</div>
    <div class="chart"><h3>User-requested goals</h3>{bar_chart(evidence.get("goal_categories") or {}, "#7c3aed")}</div>
    <div class="chart"><h3>Outcomes</h3>{bar_chart(evidence.get("outcomes") or {}, "#16a34a")}</div>
    <div class="chart"><h3>Friction</h3>{bar_chart(evidence.get("friction") or {}, "#dc2626")}</div>
    <div class="chart"><h3>Inferred satisfaction</h3>{bar_chart(evidence.get("satisfaction") or {}, "#d97706")}</div>
    <div class="chart"><h3>What helped most</h3>{bar_chart(evidence.get("success") or {}, "#0891b2")}</div>
  </div>
  <section class="ending"><h3>{esc(ending.get("headline", ""))}</h3><p>{rich_text(ending.get("detail", ""))}</p></section>
  <footer>Private local report. {esc(metadata.get("evidence_limitations", ""))} Raw transcripts were not embedded in this HTML file.</footer>
</main><script>function copyPrevious(button){{navigator.clipboard.writeText(button.previousElementSibling.innerText).then(()=>{{const old=button.textContent;button.textContent='Copied';setTimeout(()=>button.textContent=old,1200);}});}}</script></body></html>'''


def render_markdown(data: dict[str, Any], insights: dict[str, Any]) -> str:
    aggregate = data.get("aggregate") or {}
    glance = insights.get("at_a_glance") or {}
    lines = [
        "# Codex Insights", "",
        f"{aggregate.get('date_range', {}).get('start', '')} to {aggregate.get('date_range', {}).get('end', '')}", "",
        f"{aggregate.get('total_sessions', 0)} sessions · {aggregate.get('total_user_messages', 0)} user messages · {aggregate.get('total_duration_hours', 0)}h · {aggregate.get('git_commits', 0)} commits", "",
        "## At a Glance", "",
        f"**What's working:** {glance.get('whats_working', '')}", "",
        f"**What's hindering you:** {glance.get('whats_hindering', '')}", "",
        f"**Quick wins:** {glance.get('quick_wins', '')}", "",
        f"**Ambitious workflows:** {glance.get('ambitious_workflows', '')}", "",
        "## How You Use Codex", "", str((insights.get("interaction_style") or {}).get("narrative", "")), "",
        f"**Key pattern:** {(insights.get('interaction_style') or {}).get('key_pattern', '')}", "", "## What Is Working", "",
    ]
    for item in (insights.get("what_works") or {}).get("impressive_workflows") or []:
        if isinstance(item, dict):
            lines.extend([f"- **{item.get('title', '')}:** {item.get('description', '')}", ""])
    lines.extend(["## Where Things Go Wrong", ""])
    for item in (insights.get("friction_analysis") or {}).get("categories") or []:
        if isinstance(item, dict):
            lines.extend([f"- **{item.get('category', '')}:** {item.get('description', '')}", ""])
    lines.extend(["## On the Horizon", "", str((insights.get("on_the_horizon") or {}).get("intro", "")), ""])
    for item in (insights.get("on_the_horizon") or {}).get("opportunities") or []:
        if isinstance(item, dict):
            lines.extend([f"- **{item.get('title', '')}:** {item.get('whats_possible', '')}", ""])
    lines.extend([
        "## Memorable Moment", "",
        f"**{(insights.get('fun_ending') or {}).get('headline', '')}** — {(insights.get('fun_ending') or {}).get('detail', '')}", "", "---", "",
        "Private local report. Raw transcripts are not embedded in this file.", "",
    ])
    return "\n".join(lines)


def render(args: argparse.Namespace) -> int:
    input_path = Path(args.input).expanduser().resolve()
    analysis_path = Path(args.analysis).expanduser().resolve()
    output_dir = Path(args.output_dir).expanduser().resolve()
    data = read_json(input_path)
    insights = read_json(analysis_path)
    errors = validate_analysis_data(insights)
    if errors:
        raise RuntimeError("analysis validation failed: " + "; ".join(errors))
    ensure_private_dir(output_dir)
    stamp = dt.datetime.now().astimezone().strftime("%Y-%m-%d-%H%M%S")
    html_text = render_html(data, insights)
    markdown_text = render_markdown(data, insights)
    export = {
        "metadata": {
            "generated_at": iso_timestamp(dt.datetime.now(dt.timezone.utc)),
            "codex_insights_version": SCRIPT_VERSION,
            "date_range": (data.get("aggregate") or {}).get("date_range"),
            "session_count": (data.get("aggregate") or {}).get("total_sessions"),
        },
        "aggregate": data.get("aggregate"), "insights": insights,
    }
    html_path = output_dir / f"report-{stamp}.html"
    markdown_path = output_dir / f"report-{stamp}.md"
    export_path = output_dir / f"insights-{stamp}.json"
    for path, text in ((html_path, html_text), (output_dir / "report.html", html_text), (markdown_path, markdown_text), (output_dir / "report.md", markdown_text)):
        write_private_text(path, text)
    for path in (export_path, output_dir / "insights-latest.json"):
        write_private_json(path, export)
    print(json.dumps({"html_report": str(html_path), "latest_html": str(output_dir / "report.html"), "markdown_report": str(markdown_path), "json_export": str(export_path)}, ensure_ascii=False))
    return 0


def build_parser() -> argparse.ArgumentParser:
    codex_home = codex_home_from_env()
    output_dir = codex_home / "usage-data"
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    collect_parser = subparsers.add_parser("collect", help="Collect and summarize local Codex sessions")
    collect_parser.add_argument("--codex-home", default=str(codex_home))
    collect_parser.add_argument("--output-dir", default=str(output_dir))
    collect_parser.add_argument("--output")
    collect_parser.add_argument("--days", type=int, default=0, help="Only sessions started in the last N days; 0 means all")
    collect_parser.add_argument("--project", default="", help="Case-insensitive project-path substring")
    collect_parser.add_argument("--max-sessions", type=int, default=DEFAULT_MAX_SESSIONS)
    collect_parser.set_defaults(handler=collect)
    init_parser = subparsers.add_parser("init-analysis", help="Create the qualitative analysis JSON skeleton")
    init_parser.add_argument("--input", default=str(output_dir / "analysis-input.json"))
    init_parser.add_argument("--output", default=str(output_dir / "insights.json"))
    init_parser.set_defaults(handler=init_analysis)
    validate_parser = subparsers.add_parser("validate-analysis", help="Validate a completed qualitative analysis")
    validate_parser.add_argument("--input", default=str(output_dir / "insights.json"))
    validate_parser.set_defaults(handler=validate_analysis)
    render_parser = subparsers.add_parser("render", help="Render HTML, Markdown, and JSON reports")
    render_parser.add_argument("--input", default=str(output_dir / "analysis-input.json"))
    render_parser.add_argument("--analysis", default=str(output_dir / "insights.json"))
    render_parser.add_argument("--output-dir", default=str(output_dir))
    render_parser.set_defaults(handler=render)
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if getattr(args, "days", 0) < 0:
        parser.error("--days must be non-negative")
    if getattr(args, "max_sessions", 1) <= 0:
        parser.error("--max-sessions must be positive")
    try:
        return int(args.handler(args))
    except (OSError, ValueError, RuntimeError, json.JSONDecodeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
