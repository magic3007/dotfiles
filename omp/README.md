# omp (Stencil / oh-my-pi) — dotfiles 配置

`omp` 是一个 **AI coding agent harness**（不是提示符主题工具！不要和 Oh My Posh 混淆）。

- 官网: https://omp.sh
- npm/bun 包: `@oh-my-pi/pi-coding-agent`
- 安装: `curl -fsSL https://omp.sh/install | sh`（装到 `~/.bun/bin/omp`）
- 版本: omp/18.6.1

## 软链接

本目录下的**五个静态配置**被 `install.conf.yaml` 软链接进 `~/.omp/agent/`：

| repo 文件 | 软链接到 | 作用 |
|---|---|---|
| `omp/config.yml` | `~/.omp/agent/config.yml` | 全局设置：模型角色、fallback 链、压缩、状态栏 |
| `omp/models.yml` | `~/.omp/agent/models.yml` | 自定义 provider / 模型定义 |
| `omp/WATCHDOG.yml` | `~/.omp/agent/WATCHDOG.yml` | advisor（`--advisor`）的 reviewer 花名册 |
| `omp/AGENTS.md` | `~/.omp/agent/AGENTS.md` | 用户级上下文文件：回复风格（ASD-STE100 + 中文） |
| `omp/RULES.md` | `~/.omp/agent/RULES.md` | always-apply 常驻规则：同一句回复风格，长会话压缩后仍生效 |

`~/.omp/agent/` 下其余内容是**运行时状态**，各机器不同，留在本机、不进 git：

    agent.db / agent.db-wal / agent.db-shm    会话与用量状态
    history.db / models.db / skill-descriptions.db
    cache/composer.db     predict/ngram/       sessions/  terminal-sessions/
    last-changelog-version

`~/.omp/` 下同样不入库：`logs/`、`run/`（daemon socket）、`gpu_cache.json`。

### 内置 provider 不用写进 models.yml

`models.yml` 只声明**目录里没有的**自定义 provider（示例：`mafia`）。omp 的模型目录
（`@oh-my-pi/pi-catalog`）自带一批已适配的 provider——`deepseek`、`devin`、`anthropic`、
`openrouter` 等——它们的 baseUrl、wire 兼容规则、模型清单都在包里，无需在 `models.yml`
重复声明；重复声明反而要手写 api/baseUrl/models，并会丢掉内置的 compat 规则。

凭据仍按第 3 节的环境变量约定提供，例如 `deepseek` → `DEEPSEEK_API_KEY`（在
`~/.common_shell_setup_local.sh` 里 export）。启用方式是在 `config.yml` 的
`enabledModels` 里列出模型、在 `modelRoles` 里起个角色名：

    enabledModels:
      - deepseek/deepseek-v4-pro
      - deepseek/deepseek-flash
    modelRoles:
      deepseek-flash: deepseek/deepseek-flash:max

之后 `--model deepseek-flash`（角色名）或 `--model deepseek/deepseek-v4-pro` 均可直接用。
当前 `deepseek` 分组：`deepseek-v4-pro`、`deepseek-v4-flash`、`deepseek-flash`（V4.1，1M 上下文、
支持图片）、`deepseek-v4-flash-vision-exp`；thinking 档位 low/high/max。

`zai` 分组同理（目录 18 个模型，凭据 `ZAI_API_KEY`）：`glm-5.3-flash`（1M 上下文、支持图片、
目录 `thinking.mode: anthropic-budget-effort`，档位 low/high/max，`requiresEffort: true`）、
`glm-5.3`、`glm-5.2`、`glm-4.7*` 等。本机启用 `zai/glm-5.3-flash`，角色 `zai-flash`
= `zai/glm-5.3-flash:max`。

`enabledModels` 支持通配符（`model-resolver.ts` 的 `resolveGlobScopePattern` → `Bun.Glob`，
同时匹配 `provider/modelId` 与裸 id，大小写不敏感），本机用
`devin/*` 一次启用 devin 目录全部 644 个模型，无需逐个列举。

`enabledModels` 是**白名单**：只要列表非空，未被任何条目命中的模型就不可用（命中为空时
omp 直接报「没有可用模型」，不会退回内置默认）。所以启用新 provider 必须显式列出或加 glob。

默认模型由 `modelRoles.default` 决定（本机 `deepseek/deepseek-flash:auto`，即 V4.1 Flash）；
`modelRoles` 里的自定义角色名（`devin-opus` 等）只是别名，不参与默认解析。

> 迁移遗留：本机 `~/.omp/agent/{models,WATCHDOG}.yml.pre-dotfiles` 是接入 dotfiles 前的
> 原始副本（`models.yml.pre-dotfiles` 里的 `apiKey` 是占位符，不是真 key）。确认无误后可删。

## Thinking 级别（effort）

解析优先级（源码 `resolveThinkingLevelForModel`）：

1. 会话显式级别：`--thinking <level>`，或模型选择器的 `:level` 后缀（`modelRoles` 的值就是这种写法）。
2. 模型定义里的 `thinking.defaultLevel`：`models.yml` 自声明，或目录内置。
3. 全局 `defaultThinkingLevel`（本仓库现为 `auto`）。

要点：

- `auto` **只能**出现在第 1、3 层。模型定义与 `modelOverrides` 的 `defaultLevel` 只接受
  `minimal|low|medium|high|xhigh|max`；写 `auto` 会让**整个 `models.yml` 加载失败**、该
  provider 的模型全部消失（`Model "x" not found`），而 `omp models list` 仍返回 0——容易误判。
- `auto` 是逐轮分类器：按请求挑档位，上限由 `providers.autoThinkingMaxEffort`（默认 `xhigh`）
  决定。实测一个 "reply ok" 的短请求被判为 `low`。
- 目录内置的 `defaultLevel` **压过**全局 `defaultThinkingLevel`。devin 目录 528 个模型里有 38 个
  带 `defaultLevel`（`claude-opus-5-5`、`claude-fable-5-1` 都是 `medium`），这些模型只能用第 1 层
  改成 auto：角色后缀 `:auto` 或 `--thinking auto`。
- 查生效档位：会话 JSONL 里的 `thinking_level_change` 记录
  （`~/.omp/agent/sessions/<cwd>/…jsonl`），`configured:"auto"` 表示 auto 已启用，
  `thinkingLevel` 是该轮实际档位。

## Skills

omp 读 `~/.agents/skills`（`skills.enableAgentsUser`）和 `~/.omp/agent/skills`
（`skills.enablePiUser`，native user 级）以及项目级目录；`enableClaudeUser` /
`enableCodexUser` 保持 `false`，否则会和 `~/.agents/skills` 重名。

- 共享 skill（repo `skills/`）由 `scripts/sync-skills.py` 逐个链进 `~/.agents/skills`，omp 原生可见。
- omp 专属 skill 放 repo `omp/skills/<name>/`（目前没有），同一脚本链进 `~/.omp/agent/skills`。

omp 的 loader 只扫一层，对每个「目录或软链接」条目探测 `<entry>/SKILL.md`，不递归、
不读裸 `*.md`；所以视图里每个 skill 都必须是一个目录条目（脚本已保证，嵌套 bundle
会被拍平）。完整布局见仓库根 `AGENTS.md` 的 Skills 一节。

## Plugins（插件）

插件本体**不入库**。`~/.omp/plugins/` 是运行时状态：`bun install` 会重写 `package.json`
与 `bun.lock`，omp 会就地重写 `omp-plugins.lock.json`，`node_modules/` 还有上百个包。

仓库只跟踪**清单**，缺失项由安装钩子补齐：

| repo 文件 | 作用 |
|---|---|
| `omp/plugins.txt` | 每行一个 `omp plugin install` spec（`npm:` 前缀、版本后缀、`[features]` 括号均可）；空行与 `#` 注释忽略 |
| `omp/pi-fff-features.json` | pi-fff 的 feature 状态种子（关掉 `autocomplete`），由下面的 seed 钩子拷到 `~/.omp/agent/extensions/pi-fff.json` |
| `scripts/post-install.d/40-omp-plugins.sh` | `./install` 时对比 `omp plugin list --json`，只安装缺失的插件 |

要点：

- **只在 `./install` 跑**，不进 15 分钟的 `sync.sh`：安装需要网络和 `bun`。
- 已安装的插件**不重装**。重复 `omp plugin install` 不是空操作：它会重新解析包，并把 feature
  选择重置回 manifest 默认值。
- 只支持 npm spec。git / link 插件会告警跳过（GitHub 仓库名解析不出包名，无法判断是否已装）。
- 当前清单：`npm:pi-fff`（FFF 模糊查找、内容搜索；默认**覆盖内建 `read`/`grep`**，用会话内
  `/fff-features` 开关）。
- **`pi-fff` 的 `autocomplete` feature 必须保持关闭**。pi-fff 0.1.13 的
  `FffAtAutocompleteProvider` 按上游 `@mariozechner/pi-tui` 0.73 的签名实现，第 4 个参数取
  `{ signal }` 对象（`options.signal.aborted`）；omp 的 `@oh-my-pi/pi-tui` 同位置直接传
  `AbortSignal`，于是每敲一个 `@` 都抛
  `TypeError: undefined is not an object (evaluating 'options.signal.aborted')`，
  omp 记一条 `Autocomplete provider failed` 并取消补全——`@` 文件补全整个失效。
  关掉这一个 feature 后走 omp 内建的 `CombinedAutocompleteProvider`（`fuzzyFind` + 目录/图标）。
  上游修好（或 omp 补上兼容 shim）后可 `/fff-features` 重新打开，届时记得删掉下面的种子文件。
- feature 状态文件是 `~/.omp/agent/extensions/pi-fff.json`：omp 的 `getAgentDir()` 兼容 shim
  解析到 `~/.omp/agent`（实测：文件放 `~/.pi/agent/extensions/` 无效，放 `~/.omp/agent/extensions/`
  立即生效）。仓库用 `omp/pi-fff-features.json` 做种子，由
  `scripts/post-install.d/10-seed-configs.sh` 在目标缺失时拷入（已存在则不覆盖，保留你自己
  在 `/fff-features` 里的选择）。

加插件：把 spec 写进 `omp/plugins.txt`，再跑 `bash scripts/post-install.d/40-omp-plugins.sh`
（或 `./install`）。

## 状态栏（`statusLine`）

`config.yml` 里用 `preset: custom` + `rightSegments` 自定义。当前右侧：`context_pct`、
`session_name`（会话标题，无标题时该段自动隐藏）、`session`（**session id 前 8 位**，便于就地读出
`omp --fork <前缀>` / `--resume <前缀>` 要用的 id）、`subagents`、`usage`、`cache_hit`、`cost`；
左侧用 schema 默认的 `vim, model, mode, path, git, pr`。

- 预览单个 segment：`omp gallery --surface=segment --segment=session`（换成 `session_name` 等均可）。
- 合法 segment 名（omp 18.7）：`pi`、`vim`、`hostname`、`model`、`mode`、`path`、`git`、`pr`、
  `subagents`、`token_in`/`token_out`/`token_total`/`token_rate`、`cache_read`/`cache_write`/
  `cache_hit`、`cost`、`context_pct`、`context_total`、`time_spent`、`time`、`session`、
  `session_name`、`usage`、`collab`、`stream`、`status`（扩展经 `ctx.ui.setStatus()` 写的状态）。
- session id 是「epoch 毫秒的 16 进制」（如 `01a11529-2d37-…`）。`session` 段只截前 8 位 =
  毫秒 >> 16，所以**同一 ~65 秒窗口内启动的会话共享前缀**；`--fork`/`--resume` 用前缀匹配到多个时
  会静默按「最新优先」取第一个（实测），拿不准就用不带参数的 `--resume` 选择器。

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

### 4. 用户级 `AGENTS.md` 会遮蔽其他工具的用户级上下文

`~/.omp/agent/AGENTS.md` 是 native provider（优先级 100）的用户级上下文文件。它存在时，omp 只保留这一个用户级上下文文件，`~/.claude/CLAUDE.md`、`~/.codex/AGENTS.md`、`~/.gemini/GEMINI.md`、`~/.copilot/copilot-instructions.md`、`~/.agents/AGENTS.md` 都不再进入会话（claude/codex/gemini 用户源本身还需 `enabledProviders` 才启用）。项目级上下文按目录深度各留一个，不受影响。

`RULES.md` 只认 native 位置（本目录，以及项目最近的 `.omp/`）。它是 always-apply 常驻规则：正文随**每次请求**携带，长会话被压缩后仍然生效，因此必须保持很短；与 `AGENTS.md` 内容重复时会被去重。

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
