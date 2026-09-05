#!/usr/bin/env python3
"""Focused tests for the local Codex Insights collector and renderer."""

from __future__ import annotations

import argparse
import importlib.util
import json
import stat
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("codex_insights.py")
SPEC = importlib.util.spec_from_file_location("codex_insights", MODULE_PATH)
assert SPEC and SPEC.loader
insights = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(insights)


def record(timestamp: str, record_type: str, payload: dict) -> str:
    return json.dumps({"timestamp": timestamp, "type": record_type, "payload": payload}, ensure_ascii=False)


def complete_analysis(input_path: Path) -> dict:
    return {
        "schema_version": 1,
        "analysis_metadata": {
            "analysis_input": str(input_path),
            "session_sample_count": 1,
            "language": "English",
            "evidence_limitations": "One short synthetic session was analyzed.",
        },
        "at_a_glance": {
            "whats_working": "You use direct, testable requests.",
            "whats_hindering": "The sample is small.",
            "quick_wins": "Keep acceptance criteria explicit.",
            "ambitious_workflows": "Automate the verified path.",
        },
        "project_areas": {"areas": [{"name": "Testing", "session_count": 1, "description": "A parser test."}]},
        "interaction_style": {"narrative": "You iterate after evidence.", "key_pattern": "Evidence first."},
        "what_works": {"intro": "The request is concrete.", "impressive_workflows": []},
        "friction_analysis": {"intro": "Only limited evidence exists.", "categories": []},
        "suggestions": {"agents_md_additions": [], "features_to_try": [], "usage_patterns": []},
        "on_the_horizon": {"intro": "The same workflow can be repeated.", "opportunities": []},
        "fun_ending": {"headline": "A private parser test", "detail": "No raw transcript reached the report."},
        "evidence_summary": {
            "goal_categories": {"test": 1},
            "outcomes": {"fully_achieved": 1},
            "satisfaction": {},
            "friction": {},
            "success": {"correct_edits": 1},
        },
    }


class InsightsTests(unittest.TestCase):
    def test_internal_messages_and_goal_objective(self) -> None:
        payload = {
            "content": [
                {"type": "input_text", "text": "# AGENTS.md instructions for /repo\nsecret instructions"},
                {"type": "input_text", "text": "<environment_context>hidden</environment_context>"},
                {
                    "type": "input_text",
                    "text": '<codex_internal_context source="goal"><objective>Build the parser</objective><goal_status>active</goal_status></codex_internal_context>',
                },
            ]
        }
        self.assertEqual(insights.user_text_from_payload(payload), [("Build the parser", True)])

    def test_redaction(self) -> None:
        value = insights.redact("OPENAI_API_KEY=sk-proj-abcdefghijklmnopqrstuvwxyz Bearer abcdefghijklmnop")
        self.assertNotIn("abcdefghijklmnopqrstuvwxyz", value)
        self.assertNotIn("abcdefghijklmnop", value)
        self.assertIn("[REDACTED]", value)

    def test_collect_validate_and_render(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            codex_home = root / "codex"
            sessions = codex_home / "sessions" / "2026" / "08" / "29"
            sessions.mkdir(parents=True)
            session_path = sessions / "rollout-test.jsonl"
            lines = [
                record("2026-08-29T00:00:00Z", "session_meta", {"id": "session-1", "timestamp": "2026-08-29T00:00:00Z", "cwd": "/work/repo", "originator": "codex-tui", "source": "cli", "cli_version": "test"}),
                record("2026-08-29T00:00:01Z", "response_item", {"type": "message", "role": "user", "content": [{"type": "input_text", "text": "# AGENTS.md instructions for /work/repo\nignored"}]}),
                record("2026-08-29T00:00:02Z", "response_item", {"type": "message", "role": "user", "content": [{"type": "input_text", "text": "Fix the parser with API_TOKEN=super-secret-token-value"}]}),
                record("2026-08-29T00:00:10Z", "turn_context", {"model": "gpt-test"}),
                record("2026-08-29T00:01:00Z", "response_item", {"type": "message", "role": "assistant", "phase": "final_answer", "content": [{"type": "output_text", "text": "Implemented the first pass."}]}),
                record("2026-08-29T00:01:10Z", "response_item", {"type": "function_call", "name": "exec_command", "arguments": json.dumps({"cmd": "git commit -m test"})}),
                record("2026-08-29T00:01:20Z", "event_msg", {"type": "token_count", "info": {"total_token_usage": {"input_tokens": 100, "output_tokens": 20, "reasoning_output_tokens": 5, "total_tokens": 120}}}),
                record("2026-08-29T00:02:10Z", "response_item", {"type": "message", "role": "user", "content": [{"type": "input_text", "text": "Run the regression test"}]}),
                record("2026-08-29T00:02:30Z", "event_msg", {"type": "item_completed", "item": {"type": "CommandExecution", "status": "completed", "exit_code": 0}}),
                record("2026-08-29T00:03:00Z", "response_item", {"type": "message", "role": "assistant", "phase": "final_answer", "content": [{"type": "output_text", "text": "Tests pass."}]}),
            ]
            session_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
            subagent_path = sessions / "rollout-subagent.jsonl"
            subagent_lines = [
                record("2026-08-29T00:00:00Z", "session_meta", {"id": "subagent-1", "timestamp": "2026-08-29T00:00:00Z", "cwd": "/work/repo", "originator": "codex-tui", "source": {"subagent": {"thread_spawn": {"parent_thread_id": "session-1"}}}}),
                record("2026-08-29T00:00:01Z", "session_meta", {"id": "session-1", "timestamp": "2026-08-29T00:00:00Z", "cwd": "/work/repo", "originator": "codex-tui", "source": "cli"}),
                record("2026-08-29T00:00:02Z", "response_item", {"type": "message", "role": "user", "content": [{"type": "input_text", "text": "Delegated task"}]}),
                record("2026-08-29T00:02:00Z", "response_item", {"type": "message", "role": "user", "content": [{"type": "input_text", "text": "Delegated follow-up"}]}),
            ]
            subagent_path.write_text("\n".join(subagent_lines) + "\n", encoding="utf-8")
            output_dir = root / "usage-data"
            collect_args = argparse.Namespace(codex_home=str(codex_home), output_dir=str(output_dir), output=None, days=0, project="", max_sessions=50)
            self.assertEqual(insights.collect(collect_args), 0)
            input_path = output_dir / "analysis-input.json"
            collected = insights.read_json(input_path)
            self.assertEqual(collected["aggregate"]["total_sessions"], 1)
            self.assertEqual(collected["collection"]["skipped_subagent_sessions"], 1)
            self.assertEqual(collected["aggregate"]["total_user_messages"], 2)
            self.assertEqual(collected["aggregate"]["git_commits"], 1)
            self.assertNotIn("super-secret-token-value", json.dumps(collected))
            self.assertEqual(stat.S_IMODE(input_path.stat().st_mode), 0o600)

            draft = insights.analysis_skeleton(collected)
            self.assertTrue(insights.validate_analysis_data(draft))
            analysis = complete_analysis(input_path)
            self.assertEqual(insights.validate_analysis_data(analysis), [])
            analysis["fun_ending"]["detail"] = "<script>alert('x')</script>"
            html_text = insights.render_html(collected, analysis)
            self.assertNotIn("<script>alert('x')</script>", html_text)
            self.assertIn("&lt;script&gt;alert", html_text)

            analysis_path = output_dir / "insights.json"
            insights.write_private_json(analysis_path, analysis)
            render_args = argparse.Namespace(input=str(input_path), analysis=str(analysis_path), output_dir=str(output_dir))
            self.assertEqual(insights.render(render_args), 0)
            self.assertTrue((output_dir / "report.html").is_file())
            self.assertEqual(stat.S_IMODE((output_dir / "report.html").stat().st_mode), 0o600)


if __name__ == "__main__":
    unittest.main()
