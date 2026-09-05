---
name: insights
description: Analyze local Codex session history and generate a private usage report with workflow patterns, friction, recommendations, and quantitative statistics. Use when the user asks for Codex insights, a retrospective on how they use Codex, or a report based on local Codex sessions; do not use for billing, quotas, or API usage.
---

# Codex Insights

Generate a local report from Codex JSONL sessions. Keep the workflow local: do not upload transcripts, browse for enrichment, or invoke another model process. Use the current Codex turn for the qualitative analysis.

## Workflow

1. Resolve this skill directory as `${CODEX_HOME:-$HOME/.codex}/skills/insights`. If that path is unavailable, use the directory containing this `SKILL.md`.
2. Run the collector. Unless the user requests a range or project, analyze all eligible top-level sessions:

   ```bash
   python3 <skill-dir>/scripts/codex_insights.py collect
   ```

   Optional filters are `--days N`, `--project TEXT`, and `--max-sessions N`. Do not add a filter merely to reduce work.
3. Read the generated `analysis-input.json` completely. It contains aggregate statistics and bounded, redacted session excerpts; do not reopen raw session files unless the collector reports a parsing problem.
4. Create the analysis skeleton:

   ```bash
   python3 <skill-dir>/scripts/codex_insights.py init-analysis
   ```

5. Replace every placeholder in `insights.json` with evidence-based analysis in the user's language. Preserve the schema.
6. Validate and render:

   ```bash
   python3 <skill-dir>/scripts/codex_insights.py validate-analysis
   python3 <skill-dir>/scripts/codex_insights.py render
   ```

7. Return the clickable absolute path to the timestamped HTML report, plus a compact at-a-glance summary. Mention the analyzed/scanned counts and any skipped or malformed sessions.

## Analysis rules

- Use second person. Be candid and constructive, not flattering.
- Separate Codex-caused friction from user/environment friction.
- Treat satisfaction as inferred unless the excerpt contains an explicit user signal.
- Count only goals the user requested, not autonomous exploration performed by Codex.
- Ground examples in the supplied excerpts, but paraphrase them. Never reproduce credentials, private tokens, or long prompt passages.
- Recommend an `AGENTS.md` addition only when the same instruction recurs in at least two distinct sessions.
- Prefer practical Codex capabilities: Skills, MCP, subagents, `codex exec`, plugins, hooks, and project `AGENTS.md`. Verify a command with local `--help` before putting it in copyable code if it is not already confirmed by the evidence file.
- Do not mistake high tool counts for productivity. Evaluate whether the workflow reached the user's goal.
- If evidence is sparse, state that clearly and leave unsupported optional lists empty instead of inventing patterns.

## Privacy and failure behavior

Generated files live under `${CODEX_HOME:-$HOME/.codex}/usage-data/` with private permissions. The HTML report contains summaries, not raw transcripts. If collection fails, report the exact error and path; do not delete or rewrite session history.

For implementation parity notes or maintenance, read [references/claude-insights-parity.md](references/claude-insights-parity.md). Ordinary report generation does not need that reference.
