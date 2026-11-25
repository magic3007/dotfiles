# Codex Skills

Codex-only skills. `scripts/sync-skills.py` links each one into `~/.codex/skills/`
(a real local dir that also holds Codex's runtime `.system/`).

Skills useful to more than one harness belong in the repo's top-level `skills/`
instead; Codex reads those from `~/.agents/skills`.

Codex-only skills here: `insights` (Codex session analytics) and
`toil-offloading-codex` (native Codex team; the harness-neutral orchestration
rules it refers to live in the shared `skills/toil-offloading/`).

Use `/skills` in Codex CLI to browse, or mention a skill with `$skill-name`.
