# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Overview

Dotfiles repository using [Dotbot](https://github.com/anishathalye/dotbot) for installation. Stores configuration files and symlinks them to their standard locations (`~/.zshrc`, `~/.gitconfig`, `~/.config/nvim`, etc.).

## Commands

```bash
./install                                # Full installation (idempotent, safe to re-run)
./install --only link                   # Phase 1 only: create/relink symlinks (no network)
./install --only clean                  # Remove broken symlinks under ~
./install --only create                 # Create missing directories
git submodule update --init --recursive  # Update Vim plugins
```

**No dry-run flag.** This pinned Dotbot submodule has no `-n` / `--dry-run`; both fail with
`unrecognized arguments`. Preview by running the single Phase 1 directive you care about
(`--only link` is the one you want after editing the `link` section — it is idempotent, and it
refuses to overwrite an existing regular file, so a stray `~/.foo/config` must be moved aside
first).


## Architecture

### Two-Phase Installation (`install.conf.yaml`)

- **Phase 1 — Local**: Defaults, directory creation, submodules, backup existing configs, symlinks. No network required, always succeeds.
- **Phase 2 — Network**: Homebrew, platform packages, oh-my-zsh + plugins, fzf, Node.js/nvm, GitHub CLI, AI coding tools. All commands use `--connect-timeout` / `|| true` to avoid blocking without network.

### Symlink Model

All configs live in this repo and are symlinked to `~` via Dotbot. The `link` section in `install.conf.yaml` is the single source of truth for what gets symlinked where. When adding new configs: add files to the repo, then add symlink entries to `install.conf.yaml`.

### Local Customization Pattern

Machine-specific overrides go in `*_local` files (not tracked by git):
- `~/.gitconfig_local` — local git user/config (included via `[include]` in gitconfig)
- `~/.zsh_local` — local zsh config
- `~/.common_shell_setup_local.sh` — local shell setup (bash/zsh)
- `~/.codex/config_local.toml` — per-machine Codex config, merged over `codex/config.toml`
  (example: Linux hosts disable the macOS-only `[mcp_servers.node_repl]`)
- `~/.config/fish/conf.d/local.fish` — local fish config (fish is archived; see below)

### Shell Setup

Two shells are actively supported and maintained: zsh and bash.

**bash/zsh**: `common_shell_setup.sh` is sourced by both `.zshrc` and `.bashrc`. It contains shared aliases, functions, env vars, and AI tool wrappers.

**fish (ARCHIVED — do not maintain)**: fish config was moved to `archive/fish/` and is **frozen**. `install.conf.yaml` still symlinks `~/.config/fish` to that location so an existing fish login keeps working, but no fish config, aliases, functions, completions, or Fisher install steps should be added or updated. Rationale: the config was unmaintained, and its plugin list (`fish_plugins`) was deliberately removed from tracking in f3ea88f. See `archive/fish/README.md` before touching anything fish-related.

Common features across all shells:
- Safe `rm` override: `rm` is aliased to a warning; use `rem` for reversible delete or `\rm` for real delete
- Safe `mv`/`cp`: aliased with `-i` (interactive) flags
- Docker helper functions: `docker-run`, `docker-slave`, `docker-run-gui`
- AI tool shell aliases (see below)

### AI Tool Integration

Shell aliases and wrapper functions in `common_shell_setup.sh`:
- `cc` — Codex (`Codex --dangerously-skip-permissions`)
- `cx` — OpenAI Codex (`codex --full-auto`)
- `gm` — Google Gemini CLI (`gemini --yolo`)
- `oc` — Opencode
- `dscc()` — Codex with DeepSeek API backend
- `kmcc()` / `kmcc2()` — Codex with Kimi API (via OpenRouter / direct)
- `mxcc()` — Codex with MiniMax via OpenRouter
- `qwcc()` — Codex with Qwen3.5 via Aliyun

### Skills (shared vs. harness-specific)

One source per skill, one generator, generated views. Sources (repo):

| Source | Scope | Generated view | Read by |
|---|---|---|---|
| `skills/` | shared, harness-neutral | `~/.agents/skills/<name>` | Codex, Pi, omp, Cursor, Gemini natively |
| `claude/skills/` | Claude Code only | `~/.claude/skills/<name>` | Claude Code (view also gets every shared + `~/.agents` external skill, since Claude Code ignores `~/.agents/skills`) |
| `codex/skills/` | Codex only | `~/.codex/skills/<name>` | Codex (`.system/` there is Codex runtime, local) |
| `pi/skills/` | Pi only | `~/.pi/agent/skills/<name>` | Pi |
| `omp/skills/` | omp only (none yet) | `~/.omp/agent/skills/<name>` | omp |

`scripts/sync-skills.py [--dry-run]` builds all views (run by `./install` and every `sync.sh` tick). Views are real directories of per-skill symlinks — never symlink a whole view into the repo. The script:
- flattens bundles (`skills/tide/*`, `skills/scientific-agent-skills/skills/*`, …) to one entry per frontmatter `name:`; skips `examples/`, `plugins/`, `templates/`, hidden dirs;
- exposes a skill that contains nested skills (`storage-ops`, `claudeception`, `weaver_harness_hub`→`hub`) as a shim dir without the nested subtrees, so recursive loaders (Codex, Cursor) don't list children twice;
- links a top-level Claude plugin bundle without its own `SKILL.md` (`claude/skills/codepp-harbor-task`, uses hooks) whole;
- only touches symlinks into the repo / `~/.agents/skills` / legacy mirrors and its own shims; real dirs (npx installs, Codex `.system`, Claude `synced/`) are left alone and reported.

Placement rule: a skill is **shared** unless it depends on one harness — Claude-only runtime features (`` !`cmd` `` injection, `${CLAUDE_SKILL_DIR}`, plugin hooks: `hub*`, `web-access`, `codepp-harbor-task`), configures/operates that harness (`check-claude-code-config`, `claude-cron-automation`, `nvm-claude`, Codex `insights`), or generates that harness's project files (`setup-harness`, `project-starter`, `harness-generate-*`, `claude-code-custom-skill-development`). Shared skills reference their own files via `~/.agents/skills/<name>/…` (exists for every harness); Codex maps Claude Code vocabulary once in `codex/AGENTS.md`, not per skill. Per-harness opt-out of a shared skill uses the harness's own switch (Codex `[[skills.config]] enabled = false`, e.g. `ask-for-help`); the Codex toggle list is per-machine and lives in the untracked `~/.codex/config_local.toml`.

Privacy: this repo is public. Internal skills stay untracked via the explicit list in `.gitignore`; a new skill dir shows up as untracked until you either list it there or `git add` it.

Third-party installs: `npx skills add <pkg> -g` puts the skill in `~/.agents/skills/` (tracked in `~/.agents/.skill-lock.json`); lark-* live there. The harness dirs are no longer symlinks into this repo, so `-g` can't write into the repo any more; re-run `scripts/sync-skills.py` afterwards so Claude Code sees the new skill.

### AI Tool Configurations (`Codex/`, `codex/`, `gemini/`, `opencode/`, `pi/`)

Each AI coding tool has its own config directory symlinked to `~/`:
- `Codex/` → `~/.Codex/` — Codex settings, hooks, skills, rules, commands, agents
- `codex/` → `~/.codex/` — OpenAI Codex config and env
- `gemini/` → `~/.gemini/` — Gemini CLI settings
- `opencode/` → `~/.config/opencode/` — Opencode config
- `pi/` → `~/.pi/agent/` — Pi agent settings, models, extensions

**Pi extensions** (`pi/extensions/` → `~/.pi/agent/extensions/`): TypeScript 扩展，通过 `pi.on()` 订阅生命周期事件。现有扩展：
- `pi-end-reminder.ts` — 监听 `agent_settled` 事件，任务完成后通过 `~/.local/bin/wechat-reminder` 发送飞书/微信通知（对应 Claude Code 的 `claude-end-reminder.sh`）。默认通过环境变量 `END_REMINDER_ENABLE` 开关（默认关闭，见 wechat-reminder 节）。新扩展加到 `pi/extensions/` 即可自动被发现（`/reload` 热加载）。

**Pi skills**: `pi/settings.json` loads `~/.pi/agent/skills` (Pi-only view); shared skills come from `~/.agents/skills`, which Pi always auto-loads. Never add `~/.claude/skills` / `~/.codex/skills` there (duplicate names).

**omp** (`omp/`, https://omp.sh, Stencil/oh-my-pi): a coding agent harness. Five static configs are symlinked into `~/.omp/agent/`: `config.yml`, `models.yml`, `WATCHDOG.yml`, `AGENTS.md` (user-level context file), and `RULES.md` (always-apply sticky rule); the rest of `~/.omp/agent` (`*.db`, `sessions/`, `cache/`, `terminal-sessions/`, `last-changelog-version`) plus `~/.omp/{logs,run,gpu_cache.json}` is runtime state and stays local. Hard constraints on `config.yml`: (1) it MUST remain writable — omp takes a native file lock, a read-only symlink breaks every launch; (2) it does NOT support comments — `omp config set` rewrites it as pure YAML and strips comments, so keep explanatory prose in `omp/README.md`, not in the file (`models.yml`/`WATCHDOG.yml` have no rewrite path, so comments there are fine); (3) never commit `auth.*`/provider tokens/secrets — `models.yml`'s `apiKey` takes an env-var *name* (omp runs it through `$envExact`), and the real `MAFIA_API_KEY` lives in the untracked `~/.common_shell_setup_local.sh`. Install: `curl -fsSL https://omp.sh/install | sh` (→ `~/.bun/bin/omp`).

**codex config.toml is split, never symlinked**: Codex has no `include`
directive, and it edits `~/.codex/config.toml` in place at runtime, writing
machine-local state into it (`[projects.*]` trust levels, `[hooks.state]`,
`[marketplaces.*]`, `[plugins.*]`, `[notice.*]`, `[tui]` nux/screen-reader
state). A symlink therefore pushed that state into this repo — earlier commits
carried `/Users/magic/...` and `/home/yanzhou/.codex/.tmp/...` entries — and on
macOS Codex replaces the symlink with a regular file anyway. So:

- `codex/config.toml` (tracked) holds **shared** keys only: default model,
  providers, `[agents]`, `[features]`, `[shell_environment_policy]`, `[tui]`
  preferences, and `[mcp_servers.*]` definitions.
- `[[skills.config]]` toggles and `[projects.*]` trust are **user-authored
  per-machine policy**, not repo-derived state: the skill toggles live in
  `config_local.toml`, project trust in the live file.
- `~/.codex/config.toml` is a **real machine-local file** (mode 0600) that
  Codex owns; it keeps its own `[projects.*]`/`[hooks.state]`/… state.
- `scripts/codex-config-sync.py` merges `~/.codex/config_local.toml`
  (untracked overrides) over `codex/config.toml` over the live file, and
  rewrites the live file when the result differs. It also replaces an existing
  symlink with a real file even when the content is already correct.
- Precedence mirrors git config: `config_local.toml` > `codex/config.toml` >
  `~/.codex/config.toml`. A shared key can only be overridden per machine via
  `config_local.toml`, never by editing the live file.

Both `install.conf.yaml` and `sync.conf.yaml` therefore contain no
`~/.codex/config.toml` link; the merge runs from
`scripts/post-install.d/30-codex-config.sh` (install) and the `shell:` section of
`sync.conf.yaml` (15-minute tick). Add new shared keys only to
`codex/config.toml`, and never add keys Codex itself writes.

**Codex native toil team**: `codex/config.toml` registers the Responses API
providers and a flat native team capped at 50 concurrent threads. Role files
live in `codex/agents/{dspix,glmpix}.toml`; orchestration policy lives in
`codex/skills/toil-offloading/`. Keep credentials in `DEEPSEEK_API_KEY` and
`ZAI_API_KEY`, never in tracked TOML. The skill treats configured native
roles as runtime-provided options and sends useful assignments directly without
role-availability or model/provider probes.

**Codex hooks** (`~/.codex/hooks/`，本地文件未入库):
- `check_dangerous_ops.sh` (PreToolUse) — blocks destructive git commands (`reset --hard`, `push --force`, `clean -f`, etc.), prevents writes to `/tmp/`, and intercepts file deletions outside safe directories
- `check-expert-update.sh` (PostToolUse) — reminds to update docs when editing configs/scripts
- `claudeception-activator.sh` (UserPromptSubmit) — triggers knowledge extraction evaluation
- `claude-end-reminder.sh` (Stop) — sends Feishu notifications on task completion via wechat-reminder; gated by `END_REMINDER_ENABLE` (default off)

**Safe directories**: `output/`, `test_output/`, `debug_output/` are whitelisted in `check_dangerous_ops.sh` — Codex can freely write/delete within these without prompts.

**Plugins** (in `settings.json`): superpowers (official), feishu, humanize — installed via marketplace system with `extraKnownMarketplaces` config.

### Chinese Mirrors

Package managers are configured with Chinese mirrors for faster downloads:
- Rust (rsproxy.cn), Go (mirrors.aliyun.com), npm (`.npmrc`), pip (`pip.conf`), Conda/Mamba (`.condarc`/`.mambarc`), Julia (TUNA), Flutter (flutter-io.cn)

### Git Configuration

- `pull.ff = only` — fast-forward only pulls
- `push.default = upstream` — push to upstream tracking branch
- `user.useConfigOnly = true` — requires explicit user config
- `core.hooksPath = ~/.git-hooks` — custom hooks directory
- `safe.directory = *` — trusts all directories
- Extensive aliases: `st` (status), `co` (checkout), `di` (diff), `dc` (diff cached), `gr` (graph log), etc.

### Cross-Platform

- **Linux**: apt-get for zsh, tmux, vim, htop, ranger, fish (see `install-scripts/linux/`). The `fish` package is still installed so archived fish config remains usable.
- **macOS**: Homebrew for rg, lazygit, zellij, fish (see `install-scripts/mac/`); Cursor/Antigravity editor config symlinks; Karabiner keyboard remapping; skhd window management; iTerm2 plist sync via `~/.config/iterm2`; Ghostty terminal config via `ghostty/config`

When adding new platform packages, edit the relevant `install-scripts/{linux,mac}/install-packages.sh`.

### wechat-reminder (`wechat-reminder/`)

通知工具，支持 WeChat (PushDeer) 和飞书双通道。通过 Claude Code hook（Stop/StopFailure/TaskCompleted）、Codex hook（Stop）和 Pi 扩展（`agent_settled`）自动发送任务完成通知。

**开关（默认关闭）**：环境变量 `END_REMINDER_ENABLE` 控制 Claude Code（`claude/hooks/claude-end-reminder.sh`）、Codex（`~/.codex/hooks/claude-end-reminder.sh`，本地未入库）和 Pi（`pi/extensions/pi-end-reminder.ts`）三个发送端。未设置 / 空 / `0` / `false` / `no` / `off` → 不发送；设置为 `1` / `yes` / `true` / `on` → 发送。启用示例：`END_REMINDER_ENABLE=1 claude` 或 `export END_REMINDER_ENABLE=1`。

- `install.conf.yaml` 只复制 `wechat-reminder` 和 `wechat-reminder_main.py` 到 `~/.wechat-reminder/`，新增功能必须放在这两个文件内
- 飞书 `lark_md` **不支持** Markdown 表格语法（`| col | col |`），`wechat-reminder_main.py` 中的 `parse_content_segments()` 会自动将 Markdown 表格转换为飞书原生 `table` 卡片元素
- 单张卡片最多 5 个表格，超出降级为纯文本
- 环境变量：`FEISHU_WEBHOOK_URL`（飞书 webhook，支持逗号分隔多个）、`PUSHDEER_KEY`（微信推送）

### Post-install Hooks (`scripts/post-install.sh`, `scripts/post-install.d/`)

Things dotbot cannot express run as hooks after the symlinks are in place, via
`scripts/post-install.sh` (called by `./install`; the 15-minute `sync.sh` calls
only the cheap seed hook). Each hook in `scripts/post-install.d/` is idempotent
and standalone:

- `10-seed-configs.sh` — for config files whose owning tool rewrites them in
  place (kimi CLI, ...). Such a tool writes a temp file and renames it over the
  target, which replaces a symlink with a regular file, so the repo keeps a
  reference copy and copies it in **only when the target is missing**. Never put
  these in a `link:` section: dotbot then fails with "already exists but is a
  regular file or directory" and exits 1 for the whole run.
- `20-neovim-runtime.sh` — re-pins and patches the vendored Neovim plugins (see
  `neovim/README.md`), using `scripts/apply-patches.sh` as the generic
  idempotent patch applier.
- `30-codex-config.sh` — merges the tracked `codex/config.toml` into the
  machine-local `~/.codex/config.toml` via `scripts/codex-config-sync.py`; also
  runs from the `shell:` section of `sync.conf.yaml` on every 15-minute tick.

### Adding New Configs

When adding new dotfile configs:
1. Add the config file to this repo
2. Add a symlink entry to the `link` section in **both** `install.conf.yaml` and
   `sync.conf.yaml` — the 15-minute auto-sync uses its own config, so a link
   added to only one of them breaks the other run
3. If the owning tool rewrites the file in place, seed it instead — see
   "Post-install Hooks" above
4. If platform-specific, wrap in a shell condition: `test "$(uname)" = "Darwin" && ...`
