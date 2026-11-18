# mcode (MiniMax Code)

Delivery: **merge**, never link. See `docs/REPO_GUIDE.md` §2 for why.

`~/.minimax/` holds exactly one user config file — `config.yaml` (providers,
model catalog, `defaultModel`, thinking and variant defaults). Everything else
there is runtime state and stays local: `auth/`, `v2/` (sessions, sqlite runtime
state, drafts, plugin caches), `cache/`, `packages/`, `model-access/`,
`preferences/`, `plugins/`, `agents/.builtin`, `.builtin-skills/`,
`mcp-runtime-names.json`, and the `config.yaml.bak.*` files.

## Why it is merged

mcode saves config by writing `.config-tmp-<hex>` next to the file and renaming
it **over the config path itself**. Its main writer does not resolve the realpath
first — unlike its status-line writer, which does. The first write therefore
turns a symlink into a regular file; observed twice within ~15 minutes of
ordinary use on 2026-11-13. The next Dotbot run then aborts the whole link
section.

Triggers include the shift+tab permission picker, `mcode provider add/remove`,
default-model changes, and the legacy BYOK provider migration.

`scripts/mcode-config-sync.py` merges `mcode/config.yaml` into the live file:
repo-defined keys win, local-only keys (model-discovery results, `tui.*`) survive
verbatim, a leftover symlink is healed into a regular file, and the previous live
file is kept as `config.yaml.pre-sync`. It runs from
`scripts/post-install.d/40-mcode-config.sh` and on every 15-minute tick.

**Consequence**: a setting toggled in the TUI is reverted at the next sync.
Change `mcode/config.yaml` instead.

## Credentials

Both mafia providers' `options.apiKey` are committed as the literal reference
`'${MAFIA_API_KEY}'`. mcode expands `${NAME}` from its own process environment
for `custom_provider.<id>.options.apiKey` and `minimax_api.apiKey` — a bare
`$NAME` or `{env: NAME}` is **not** expanded — and it preserves the reference
text when rewriting the file for unrelated settings.

The real key lives in the untracked `~/.common_shell_setup_local.sh`, so a
Desktop or GUI launch that does not source it fails those providers with a
named-variable error.

## Permission mode

The TUI root command registers **no** `--permission` option (verified:
`mcode --permission x` → `error: unknown option`; only `mcode exec` and
`mcode acp` take `--permission ask|smart|full|off`), and there is no env
override. The mode comes solely from the top-level `permissionMode` key, which
the TUI's shift+tab picker also writes back.

`mcode/config.yaml` pins `permissionMode: bypassPermissions` (full access, skip
all permission checks), so that applies to every launch on every synced machine.

| Value | Meaning |
|---|---|
| `default` | ask |
| `auto` | smart |
| `acceptEdits` | accept edits |
| `bypassPermissions` | full access (pinned here) |
| `off` | disables the check pipeline entirely; the product labels it internal/unattended-only |

## Skills

mcode needs no generated view: it discovers `~/.agents/skills` (user scope) and
`<workspace>/.agents/skills` (workspace scope) natively — the same shared view
omp, Pi and Codex read — plus `~/.codex/skills`. There is deliberately no mcode
entry in `scripts/sync-skills.py`.

## Aliases

`mxmc` (M3.1-Flash), `mpmc` (M78) and `momc` (`mafia-anthropic/claude-opus-5-5`)
live in the untracked `~/.common_shell_setup_local.sh`, next to the omp ones.
