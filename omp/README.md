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

omp 读 `~/.agents/skills`（`skills.enableAgentsUser`）和 `~/.omp/agent/skills`
（`skills.enablePiUser`，native user 级）以及项目级目录；`enableClaudeUser` /
`enableCodexUser` 保持 `false`，否则会和 `~/.agents/skills` 重名。

- 共享 skill（repo `skills/`）由 `scripts/sync-skills.py` 逐个链进 `~/.agents/skills`，omp 原生可见。
- omp 专属 skill 放 repo `omp/skills/<name>/`（目前没有），同一脚本链进 `~/.omp/agent/skills`。

omp 的 loader 只扫一层，对每个「目录或软链接」条目探测 `<entry>/SKILL.md`，不递归、
不读裸 `*.md`；所以视图里每个 skill 都必须是一个目录条目（脚本已保证，嵌套 bundle
会被拍平）。完整布局见仓库根 `AGENTS.md` 的 Skills 一节。

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
