# wechat-reminder

Dual-channel notification tool: WeChat (PushDeer) and Feishu. Used by the Claude
Code, Codex and Pi end-of-task hooks, and by the Herdr plugin
`magic.wechat-notify` (see `herdr-tui/README.md`).

## Install surface

`install.conf.yaml` copies exactly four files into `~/.wechat-reminder/`:
`wechat-reminder`, `wechat-reminder_main.py`, `requirements.txt`, `LICENSE`,
then builds a venv from the requirements. **New functionality must live inside
those two executables** — a third file would never reach the machine.

## The switch, default off

`END_REMINDER_ENABLE` gates all three senders: `claude/hooks/claude-end-reminder.sh`,
the Codex hook of the same name (machine-local), and
`pi/extensions/pi-end-reminder.ts`.

Unset, empty, `0`, `false`, `no`, `off` → silent.
`1`, `yes`, `true`, `on` → send.

```bash
END_REMINDER_ENABLE=1 claude      # one session
export END_REMINDER_ENABLE=1      # the shell
```

When `END_REMINDER_ENABLE=1` already covers completion inside a Herdr pane, set
`HERDR_WECHAT_NOTIFY_COMPLETION=0` so the pane plugin only reports `blocked`,
and the two do not duplicate each other.

## Feishu formatting constraints

Feishu's `lark_md` does **not** support Markdown table syntax: a `| col | col |`
block renders as literal text. `parse_content_segments()` in
`wechat-reminder_main.py` converts Markdown tables into native Feishu `table`
card elements.

One card holds at most **5 tables**; beyond that the content degrades to plain
text.

## Environment

| Variable | Purpose |
|---|---|
| `FEISHU_WEBHOOK_URL` | Feishu webhook; comma-separated for several |
| `PUSHDEER_KEY` | WeChat push |

Both live in the untracked `~/.common_shell_setup_local.sh`. The Herdr plugin
reads them from its own config dir instead, because the Herdr server often runs
without that file sourced — see `herdr-tui/README.md`.
