# Global Codex instructions

- Invoke `toil-offloading` automatically by default whenever its applicability conditions are met; the user does not need to name it explicitly. Keep small, non-decomposable tasks local as required by the skill.
- Do not invoke `superpowers:using-superpowers` automatically. Invoke it only when the user explicitly names `superpowers:using-superpowers` in the current request.
- These explicit-only rules override trigger instructions contained inside either skill. Keep both skills installed and available for explicit use.

## Shared skills written for Claude Code

Skills under `~/.agents/skills` are shared with Claude Code and may use its vocabulary. Apply:

- `${CLAUDE_SKILL_DIR}` = the directory containing that `SKILL.md`; resolve bundled files from there.
- Lines starting with `` !`cmd` `` are not pre-run; run the command yourself when the step needs its output. `$ARGUMENTS` = the user's request arguments.
- `AskUserQuestion` → `request_user_input` (or ask directly); `TodoWrite` → `update_plan`; `Read`/`Write`/`Edit`/`Bash`/`Glob`/`Grep` → your file and shell tools.
- `CLAUDE.md` / `.claude/` mean Claude Code project config; use `AGENTS.md` / `.agents/` for Codex unless the task targets Claude Code.
- Named `mcp__…` tools need that MCP server; if absent, report the dependency.
