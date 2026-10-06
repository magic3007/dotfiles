# Codex Skills

Codex-only skills. `scripts/sync-skills.py` links each one into `~/.codex/skills/`
(a real local dir that also holds Codex's runtime `.system/`).

Skills useful to more than one harness belong in the repo's top-level `skills/`
instead; Codex reads those from `~/.agents/skills`.

Codex-only skills here: `insights` (Codex session analytics) and
`toil-offloading` (native Codex team). The former `$create-pr`, `$gen-commit-msg`,
`$pr-review`, `$smart-commit` copies were merged into the shared `skills/` versions.

Use `/skills` in Codex CLI to browse, or mention a skill with `$skill-name`.
