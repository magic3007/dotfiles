# omp (Stencil / oh-my-pi) — dotfiles 配置

`omp` 是一个 **AI coding agent harness**（不是提示符主题工具！不要和 Oh My Posh 混淆）。

- 官网: https://omp.sh
- npm/bun 包: `@oh-my-pi/pi-coding-agent`
- 安装: `curl -fsSL https://omp.sh/install | sh`（装到 `~/.bun/bin/omp`）
- 版本: omp/18.6.1

## 软链接

本目录下的**三个静态配置**被 `install.conf.yaml` 软链接进 `~/.omp/agent/`：

| repo 文件 | 软链接到 | 作用 |
|---|---|---|
| `omp/config.yml` | `~/.omp/agent/config.yml` | 全局设置：模型角色、fallback 链、压缩、状态栏 |
| `omp/models.yml` | `~/.omp/agent/models.yml` | 自定义 provider / 模型定义 |
| `omp/WATCHDOG.yml` | `~/.omp/agent/WATCHDOG.yml` | advisor（`--advisor`）的 reviewer 花名册 |

`~/.omp/agent/` 下其余内容是**运行时状态**，各机器不同，留在本机、不进 git：

    agent.db / agent.db-wal / agent.db-shm    会话与用量状态
    history.db / models.db / skill-descriptions.db
    cache/composer.db     predict/ngram/       sessions/  terminal-sessions/
    last-changelog-version

`~/.omp/` 下同样不入库：`logs/`、`run/`（daemon socket）、`gpu_cache.json`。

> 迁移遗留：本机 `~/.omp/agent/{models,WATCHDOG}.yml.pre-dotfiles` 是接入 dotfiles 前的
> 原始副本（`models.yml.pre-dotfiles` 里的 `apiKey` 是占位符，不是真 key）。确认无误后可删。

## Skills

omp 只读 `~/.omp/agent/skills`（provider `native`，user 级，由
`skills.enablePiUser` 控制）、`~/.agents/skills` 和项目级目录
（`.agents/skills`、`.claude/skills`）。**它不读 `~/.pi/agent/skills`、
`~/.claude/skills`、`~/.codex/skills`**，所以 `~/.omp/agent/skills` 必须是一份镜像：

    ./install            # 会跑 scripts/sync-omp-skills.sh
    scripts/sync-omp-skills.sh [--dry-run]

优先级 `~/.agents/skills` > `~/.claude/skills` > `~/.codex/skills`，按 frontmatter 的
`name:` 去重，缺 `description` 的跳过。

**链接必须是目录软链接，不能是 `<name>.md -> .../SKILL.md`。**
omp 的 loader（`loadSkillsFromDir` → `fp()`，`dist/cli.js`）用
`readdir(withFileTypes)` 遍历，然后对每个「目录或软链接」条目只探测
`<entry>/SKILL.md`，既不递归也不读裸 `*.md` 文件：

    for (const entry of dirents) {
      if (!entry.isDirectory() && !entry.isSymbolicLink()) continue
      const md = join(dir, entry.name, "SKILL.md")
      if (existsSync(md)) push(read(md))
    }

所以 `claudeception.md -> ~/.claude/skills/claudeception/SKILL.md` 会被**静默丢弃**
（它去找的是 `claudeception.md/SKILL.md`）。Pi 接受这种根级 `.md` skill，omp 不接受——
这就是「Pi 里有 claudeception、omp 里没有」的原因。容器型 skill
（`claudeception` / `storage-ops` / `weaver_harness_hub`）链**目录**即可，
omp 只读一层，不会带出嵌套子 skill。

`~/.omp/agent/skills` 本身是运行时目录（不入 git），由上述脚本重建。

## 硬性约束

### 1. `config.yml` 必须可写

omp 会对 config.yml 上 native file lock，只读符号链接或只读 store 文件会导致每次启动报
`Failed to acquire native file lock … Permission denied`。repo 里的 `omp/config.yml`
保持**普通可写文件**（当前权限 `600`），omp 的原子写会保留 symlink target。

### 2. `config.yml` 不支持注释

`omp config set/reset` 重写文件时会按纯 YAML 重新序列化并**剥离注释**。所以：

- **说明性文字一律放本 README 或 `AGENTS.md`，不要写进 `config.yml`。**
- （例外：`models.yml` / `WATCHDOG.yml` 没有 `omp config set` 这类重写路径，注释可以留，
  本仓库在 `models.yml` 里保留了 apiKey 的取值说明。）

### 3. 不要存密钥

`auth.*` / provider token / broker 凭据等敏感信息**绝不入库**。

`models.yml` 的 `apiKey` 字段值会先过 omp 的 `resolveConfigValue()`（见
`src/config/resolve-config-value.ts`），三种取值方式按顺序判断：

1. 以 `!` 开头 → 执行 shell 命令，取 stdout（结果缓存，失败 30s 退避）
2. 整串是一个**精确匹配的环境变量名**（`$envExact`）→ 读该环境变量
3. 都不是 → 当**字面量**用

所以入库写法是**只写变量名**：

    providers:
      mafia:
        apiKey: MAFIA_API_KEY      # 真实 key 在 ~/.common_shell_setup_local.sh 里 export

`~/.common_shell_setup_local.sh` 不入库，所以密钥不跟仓库走。
⚠️ 若该环境变量未设置，`$envExact` 返回 `undefined`，omp 会退化成把字面量
`MAFIA_API_KEY` 当 key 用 → 401。排查时先确认 `MAFIA_API_KEY` 已 export。

## 常用命令

    omp config list                  # 查看所有 key + 当前/默认值
    omp config set   <key> <value>   # 设置并持久化到 config.yml（写透 symlink）
    omp config get   <key>           # 读取
    omp config reset <key>           # 恢复默认
    omp config path                  # 打印 agent 配置目录 (~/.omp/agent)
    omp models list                  # 确认 models.yml 生效（应出现 mafia 分组）
    omp --advisor                    # 启用 WATCHDOG.yml 里的 advisor

`config` 的 key 是**扁平**格式：`omp config set theme.dark titanium` 对应嵌套
`theme: { dark: titanium }`。只写入被覆盖的 key，其余 deep-merge 默认值。

## 可选：纳入更多静态配置

若想跟踪 agents / skills / hooks，可用 `omp agents unpack`（默认写到
`~/.omp/agent/agents`）后软链接对应子目录。当前按需再补。

新增静态配置时记得同步三处：repo 文件、`install.conf.yaml` 的 link 段、本 README 表格。
