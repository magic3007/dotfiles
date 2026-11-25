# Codex

Delivery: **merge**, never link. See `docs/REPO_GUIDE.md` §2 for why.

## config.toml is split in three

Codex has no `include` directive and edits `~/.codex/config.toml` in place,
writing machine-local state into it: `[projects.*]` trust levels,
`[hooks.state]`, `[marketplaces.*]`, `[plugins.*]`, `[notice.*]`, `[tui]` nux and
screen-reader state. A symlink pushed all of that into this repository — earlier
commits carried `/Users/magic/...` and `/home/yanzhou/.codex/.tmp/...` entries —
and on macOS Codex replaces the symlink with a regular file anyway.

| File | Tracked | Holds |
|---|---|---|
| `codex/config.toml` | yes | shared keys: default model, providers, `[agents]`, `[features]`, `[shell_environment_policy]`, `[tui]` preferences, `[mcp_servers.*]` |
| `~/.codex/config_local.toml` | no | per-machine policy: `[[skills.config]]` toggles, anything overriding a shared key |
| `~/.codex/config.toml` | no | the live file Codex owns, mode 0600, with its own state |

Precedence mirrors git config: `config_local.toml` > `codex/config.toml` >
the live file. `scripts/config-merge.py` merges them and rewrites the live file
when the result differs; it also replaces a leftover symlink with a real file
and keeps the previous content as `config.toml.pre-sync`. `scripts/apply.sh`
runs it on every install and every 15-minute tick.

Add shared keys only to `codex/config.toml`. Never add keys Codex writes itself.

A shared key can only be overridden per machine through `config_local.toml`,
never by editing the live file — the next sync would revert it.

## Native toil team

`codex/config.toml` registers the Responses API providers and a flat native team
capped at 50 concurrent threads. Role files are `codex/agents/dspix.toml` and
`codex/agents/glmpix.toml`; the orchestration policy is the shared
`skills/toil-offloading/` (`SKILL.md` + `references/assignment-brief.md`), with
the Codex runtime wrapper in `codex/skills/toil-offloading-codex/`.

Credentials stay in `DEEPSEEK_API_KEY` and `ZAI_API_KEY`, never in tracked TOML.

The skill treats configured native roles as runtime-provided options: it sends
assignments directly, without role-availability or model/provider probes.

## Hooks

`~/.codex/hooks/` is machine-local and untracked.

| Hook | Event | Does |
|---|---|---|
| `check_dangerous_ops.sh` | PreToolUse | blocks `reset --hard`, `push --force`, `clean -f`; blocks writes to `/tmp/`; intercepts deletions outside the safe directories |
| `check-expert-update.sh` | PostToolUse | reminds to update docs after config/script edits |
| `metaception-activator.sh` | UserPromptSubmit | triggers knowledge extraction |
| `claude-end-reminder.sh` | Stop | Feishu notification, gated by `END_REMINDER_ENABLE` |

Safe directories whitelisted in `check_dangerous_ops.sh`: `output/`,
`test_output/`, `debug_output/`.

Hooks need `[features] hooks = true` in the live config and one `/hooks` trust
confirmation inside Codex.

## Skills

`codex/skills/` holds Codex-only skills; everything shared comes from
`~/.agents/skills`, built by `scripts/sync-skills.py`. `codex/skills/.system/`
is Codex runtime and stays local.

Per-harness opt-out of a shared skill uses Codex's own switch
(`[[skills.config]] enabled = false`), and the toggle list is per-machine, so it
belongs in `config_local.toml`.

Codex maps Claude Code vocabulary once, in `codex/AGENTS.md`, not per skill.
