# Claude Code `/insights` parity notes

These notes document the behavior used to design this Codex adaptation. They are maintenance guidance, not instructions for ordinary report generation.

## Studied release

- Claude Code: `2.1.251`
- Build: `2026-08-28T14:51:38Z`
- Embedded git SHA: `37534ac596d80cefb02d272f036adba4ba055d2c`
- Published package: `@anthropic-ai/claude-code`

Claude Code is distributed as a native executable rather than an open source repository. The published executable contains bundled JavaScript modules. The behavior below was recovered from the local published package's embedded `insights` module and independently reimplemented; no Anthropic implementation code is shipped in this skill.

## Observed pipeline

1. Enumerate top-level local session transcripts, excluding agent branches and journals.
2. Extract deterministic session metadata: time, project, message and token counts, tools, languages, git activity, interruptions, errors, changed lines/files, and feature use.
3. Reuse cached metadata when the transcript has not changed. Refresh no more than 200 missing or stale sessions in one run.
4. Keep sessions with at least two user messages and at least one minute of duration.
5. Extract model-inferred facets for no more than 50 uncached sessions: user goal, goal category, outcome, satisfaction, helpfulness, session type, friction, primary success, and a short summary.
6. Aggregate statistics and facets, then generate qualitative sections in parallel.
7. Render a private local HTML file plus a stable `report.html` copy under the product's usage-data directory.

The Claude report sections are: At a Glance, project areas, interaction style, effective workflows, friction, configuration additions, features to try, new usage patterns, future opportunities, a memorable moment, and quantitative charts. Its per-session facets are model estimates, not ground truth.

## Codex adaptation decisions

- Input is `${CODEX_HOME:-$HOME/.codex}/sessions/**/*.jsonl`.
- Codex-internal attachments (`AGENTS.md`, environment blocks, injected Skill bodies, and goal-control text) are excluded from user-message counts. The user-authored `<objective>` in a goal continuation is retained once.
- Subagent sessions are excluded from the top-level report, matching Claude's agent-branch exclusion.
- The collector performs deterministic local parsing and redaction. The current Codex turn supplies qualitative judgment, because a Skill script cannot call the already-running model as an internal function.
- The report recommends Codex-native capabilities and `AGENTS.md`, not Claude-specific commands or `CLAUDE.md`.
- Output files use mode `0600`; the output directory uses mode `0700`.

## Known differences

- This implementation parses all selected metadata on each run instead of maintaining Claude's per-session facet cache.
- Tool and changed-line counts are best-effort across evolving Codex JSONL schemas.
- It does not collect remote-host sessions.
- It produces Markdown and JSON companions in addition to HTML.
