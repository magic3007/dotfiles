# Herdr

`config.toml` is linked to `~/.config/herdr/config.toml` by `install.conf.yaml`
and `sync.conf.yaml`.

## Local plugins

Plugins live in `plugins/<name>/` and are registered by
`scripts/herdr-plugin-link.sh` (post-install hook `70-herdr-plugin.sh`, plus the
Herdr section of `install.conf.yaml`'s network phase). The script is
idempotent and leaves a disabled plugin disabled.

### `magic.wechat-notify`

`plugins/wechat-notify/` sends a `wechat-reminder` message when Herdr reports
an agent that needs a human:

- `blocked` — approval or question dialog (`⚠️ Herdr 需要人工介入`)
- `done` — background work finished unseen (`✅ Herdr 任务完成`)
- `working` → `idle` — the active turn finished in a focused tab (`✅ Herdr 任务完成`)

The plugin is a Herdr event hook on `pane.agent_status_changed`; it does not
poll. `notify.py` keeps the previous status per pane under
`HERDR_PLUGIN_STATE_DIR/state.json` (default
`~/.local/state/herdr/plugins/magic.wechat-notify/state.json`), so a repeated
event for the same status is ignored and a plugin/server restart does not
re-notify an unchanged state.

Completion and `done` messages include the agent's final reply (`**回复**`).
The reply comes from the agent's own transcript, not the terminal screen:
`herdr agent list` gives the pane's `agent_session` path and `notify.py` reads
the last `assistant` message from it. Only `omp` sessions are adapted so far;
other agent kinds send without a reply block until their transcript format is
added to `agent_reply()`.

OMP reports precise lifecycle state only through Herdr's lifecycle hook; install
it with `herdr integration install omp` (the install network phase does this
when `omp` is present). Claude Code and Codex use Herdr's built-in screen
manifest and need no extra integration for `blocked` detection.

`wechat-reminder` receives `FEISHU_WEBHOOK_URL` / `PUSHDEER_KEY` from the Herdr
server environment. When Herdr is started without them (for example by Herdr
app), put them in the plugin env file:

```sh
herdr plugin config-dir magic.wechat-notify
# edit <printed path>/.env
```

Optional flags, readable from the process environment or that `.env`:

| Variable | Default | Effect |
|---|---|---|
| `HERDR_WECHAT_ENABLED` | on | master switch |
| `HERDR_WECHAT_NOTIFY_BLOCKED` | on | notify on `blocked` |
| `HERDR_WECHAT_NOTIFY_COMPLETION` | on | notify on `done` / `working`→`idle` |
| `HERDR_WECHAT_DRY_RUN` | off | print instead of sending |
| `HERDR_WECHAT_INCLUDE_REPLY` | on | append the agent's final reply |
| `HERDR_WECHAT_REPLY_CHARS` | 800 | reply character cap (`0` = unlimited) |

If the agent's own reminder is already enabled inside the pane
(`END_REMINDER_ENABLE=1`), set `HERDR_WECHAT_NOTIFY_COMPLETION=0` to keep only
the blocked notification and avoid duplicate completion messages.

## Verify

```sh
herdr plugin list --json
herdr plugin action invoke magic.wechat-notify.test

HERDR_WECHAT_DRY_RUN=1 HERDR_PLUGIN_STATE_DIR="$(mktemp -d)" \
  HERDR_PLUGIN_EVENT_JSON='{"event":"pane.agent_status_changed","data":{"pane_id":"wJ:p1","agent":"omp","agent_status":"blocked"}}' \
  python3 herdr/plugins/wechat-notify/notify.py

herdr pane report-agent <pane_id> --source notify-test --agent omp --state working
herdr pane report-agent <pane_id> --source notify-test --agent omp --state blocked
herdr plugin log list --plugin magic.wechat-notify
```

`pane report-agent` is the same API the official integrations use; report
`working`, then `blocked` or `idle`, and check the plugin log and the incoming
message. Release the fake state afterwards with
`herdr pane release-agent <pane_id> --source notify-test --agent omp`.
