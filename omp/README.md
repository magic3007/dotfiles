# omp (oh-my-pi) — dotfiles 配置

`omp` 是一个 **AI coding agent harness**（不是提示符主题工具，不要和 Oh My Posh 混淆）。

- 官网: https://omp.sh
- npm/bun 包: `@oh-my-pi/pi-coding-agent`
- 安装: `curl -fsSL https://omp.sh/install | sh`。两种落点：**有 bun**（≥1.4.4、架构匹配）时走
  `bun install -g`，产物是 `~/.bun/bin/omp`（`#!/usr/bin/env bun` shim）；**没有 bun** 时退化为
  下载预编译 ELF，直接写 `~/.local/bin/omp`（`PI_INSTALL_DIR` 的默认值）。

本目录跟踪的配置是 `omp/config.yml`（全局设置）、`omp/models.yml`（provider 定义）、
`omp/gateways-login.json`（网关清单）。**具体值只在文件里**，本文不抄：

    omp config list / omp config get <key>    当前生效值
    omp models / omp models <provider>        已加载的模型
    omp gallery --surface=segment             状态栏可用的 segment

抄进文档的值会过期：omp 自己会改写 `config.yml`（见「降级链与角色」）。

## 软链接

本目录下的**六个静态配置**和 `extensions/` 下的文件被 `install.conf.yaml` 软链接进 `~/.omp/agent/`：

| repo 文件 | 软链接到 | 作用 |
|---|---|---|
| `omp/config.yml` | `~/.omp/agent/config.yml` | 全局设置：模型角色、fallback 链、压缩、状态栏 |
| `omp/models.yml` | `~/.omp/agent/models.yml` | 自定义 provider / 模型定义 |
| `omp/gateways-login.json` | `~/.omp/agent/gateways-login.json` | `omp-model-gateway` 插件的网关清单（key 写引用） |
| `omp/WATCHDOG.yml` | `~/.omp/agent/WATCHDOG.yml` | advisor（`--advisor`）的 reviewer 花名册 |
| `omp/AGENTS.md` | `~/.omp/agent/AGENTS.md` | 用户级上下文文件：回复风格（ASD-STE100 + 中文） |
| `omp/RULES.md` | `~/.omp/agent/RULES.md` | always-apply 常驻规则：回复风格 + 委派硬规则 |
| `omp/extensions/deepen.ts` | `~/.omp/agent/extensions/deepen.ts` | `/deepen` 扩展，见下文 |

`~/.omp/agent/` 下其余内容是**运行时状态**，各机器不同，留在本机、不进 git：

    agent.db / agent.db-wal / agent.db-shm    会话与用量状态
    history.db / models.db / skill-descriptions.db
    cache/composer.db     predict/ngram/       sessions/  terminal-sessions/
    last-changelog-version

`~/.omp/` 下同样不入库：`logs/`、`run/`（daemon socket）、`gpu_cache.json`。

### `~/.local/bin/{bun,omp}`（给 xmatrix 探测用）

`install.conf.yaml` / `sync.conf.yaml` 还把 `~/.bun/bin/{bun,omp}` 软链到 `~/.local/bin/`。

xmatrix 的 harness 探测只看 **daemon 进程的 PATH**。daemon 由 systemd 单元
`~/.config/systemd/user/xmatrix-daemon.service` 启动，单元里写死的 PATH 是
`~/.local/bin:~/.cargo/bin:/opt/homebrew/bin:/usr/local/bin:~/bin:/usr/bin:...`，**不含 `~/.bun/bin`**，
所以 omp 在 Hub 侧一直显示 `missing`。`xmatrix harness list --local` 用的是当前 shell 环境
（PATH 含 `~/.bun/bin`），会显示 ok——两者不一致时问题在 daemon。

bun 也要链：omp 的 shim 是 `#!/usr/bin/env bun`。

两条 link 都带 `force: true`，这是**必需**而不是保险：没有 bun 的机器上，omp.sh 会把预编译 ELF
直接写到 `~/.local/bin/omp`（正是软链的目的地），留下一个普通文件；dotbot 遇到
「already exists but is a regular file」会中止**整个 link 段**，不是跳过这一条。
`force` 只在 `if`（`~/.bun/bin/<name>` 可执行）成立时才生效，所以不会删掉唯一的 omp。

从「ELF 装在 `~/.local/bin`」迁到「bun 版在 `~/.bun/bin`」时，先手工归档旧 ELF 再重链，
`force` 不会替你保住旧文件：

    mv ~/.local/bin/omp ~/.wastebasket/omp-$(omp --version | tr / -)-elf
    curl -fsSL https://omp.sh/install | sh      # 有 bun 时产出 ~/.bun/bin/omp
    ./install --only link                       # 建 ~/.local/bin/omp 软链

不要改用「改单元 PATH」的办法：`xmatrix setup daemon` 会用固定列表重写单元，覆盖手改；
软链不受影响，也不用重启 daemon。改完 `xmatrix harness refresh`，用
`xmatrix harness status <harness:id>` 看结果。

同源问题（本机未链）：`claude`（在 `~/.nvm/versions/node/*/bin`）、
`kimi`（`~/.kimi-code/bin`）、`opencode`（`~/.opencode/bin`）同样不在 daemon PATH 里，
Hub 侧也报 missing。

## Provider 的三种来源

| 来源 | 定义在哪 | 用在哪 |
|---|---|---|
| 内置目录 `@oh-my-pi/pi-catalog` | omp 包自带 | 已适配的 provider（`deepseek`、`anthropic`、`openrouter` 等） |
| `omp/models.yml` 静态块 | 本目录 | 目录里没有的 provider，或只取一个上游模型的自建入口 |
| 网关 | `omp/gateways-login.json` + `omp-model-gateway` 插件 | 一个 baseUrl + key 后面挂一整批模型 |

### 内置 provider 不写进 `models.yml`

目录已带 baseUrl、wire 兼容规则、模型清单与 compat 规则。在 `models.yml` 重复声明要手写这些
字段，并会丢掉内置 compat，所以只写目录里没有的。凭据仍来自环境变量（在
`~/.common_shell_setup_local.sh` 里 export；引用规则见「硬性约束」第 3 条）。

`enabledModels` 是**白名单**：列表非空时，未被任何条目命中的模型不可用；命中为空时 omp 直接报
「没有可用模型」，不退回内置默认。所以启用新 provider 必须显式列出或加 glob。
`enabledModels` 支持通配符（`model-resolver.ts` 的 `resolveGlobScopePattern` → `Bun.Glob`，
同时匹配 `provider/modelId` 与裸 id，大小写不敏感），`provider/*` 可一次启用该 provider 的全部
发现结果。

`modelRoles` 把角色名解析成 `<provider>/<modelId>[:<level>]`：`--model <role>` 与
`--model <provider>/<modelId>` 等价。角色只是别名，只有 `default` 与 `@task` / `@worker` /
`@reviewer` 这类被显式引用的名字参与解析。

### `models.yml`：自定义 provider

网关与内置目录的模型发现都**不返回窗口/输出上限**（`token_limits` 缺失）：网关 provider 落插件
兜底 200000 / 64000，两个数字都偏小。所以大窗口模型要在 `models.yml` 里按 **provider+id**
显式声明 `contextWindow` / `maxTokens`，只覆盖需要的 id，其余仍用兜底值。上游的 `max_tokens`
参数校验上限不等于真实生成上限，别把前者当后者写。

`apiKey` 写引用而非环境变量名，原因与写法见「硬性约束」第 3 条。

### Gateway provider（`gateways-login.json`）

目录里没有、也不是手写 `models.yml` 的第三类 provider：**网关**。`omp-model-gateway` 插件把
`~/.omp/agent/gateways-login.json` 里每个网关注册成一个 provider，字段是
`name` / `baseUrl` / `api` / `apiKey` / `extraModels`。该文件已入库（软链接，见上表）：
`apiKey` 写的是 **key 引用**而非密钥，插件存引用、omp 解析，所以文件里不含密钥。

模型清单由 `GET <baseUrl>/v1/models` 发现，再并上 `extraModels` 的静态 id。发现结果的 `id`
可能是网关混淆过的反转串；插件解出可读 id 并缓存进 `models.db` 的 `model_cache`。手改该文件后
执行 `omp models refresh`。

新增/修改走会话内 `/login` 的 gateway 入口（输入环境变量名或 `!命令` 即可；直接粘贴明文 key
时，若该 key 已存在于某个环境变量，插件会改存那个变量名并说明）。

**火山引擎不走网关**：它是 `models.yml` 里的静态 provider。Ark Coding Plan 的模型发现会带回
整批模型，而本机只用其中少数几个；静态声明让 `omp models <provider>` 只出现真正能用的 id。
这条不依赖 `omp-model-gateway` 插件，但 `enabledModels` 白名单里仍要列出（语义同上）。

`--profile <name>` 会把插件目录也隔离：profile 下 `omp plugin list` 是空的，网关 provider 与其
模型都不存在；`models.yml` 与 profile 的配置文件也不共用。要在 profile 里复现这套配置，得先
装插件、重建 `gateways-login.json`，并补上 `models.yml` 的对应块。

## 凭据在 daemon 拉起的进程里取不到

xmatrix 的 daemon 子进程环境 = daemon env + `XMATRIX_*`（看 `/proc/<run pid>/environ`）。
没有下面的 drop-in 时，daemon 环境里没有任何 `*_API_KEY`，于是凭据只来自环境变量的 provider
全部失败（变量名被当 key 发出 → 401）：

| harness | 凭据来源 | xmatrix run 里 |
|---|---|---|
| omp 网关 | `gateways-login.json` 的 `!命令` 引用 | 可用（omp 自己执行命令） |
| omp 手写 provider | `models.yml` 的 `!命令` 引用 | 同上 |
| omp 内置目录 provider | 环境变量 | 无 drop-in 时失败 |
| codex 自定义 provider | `config.toml` 的 `env_key` | 同上 |
| codex 官方 / claude / gemini | 文件式（`~/.codex/auth.json`、`~/.claude/.credentials.json`、`~/.gemini/*`） | 可用（不依赖 env） |
| omp vault（`omp login` 存过的 provider） | omp 自己的凭据库 | 可用；网关 provider 不吃 vault |

**做法**：`scripts/xmatrix-daemon-secrets.sh`（`./install` 与 15 分钟 sync 都会跑）写一个
systemd drop-in，让 daemon 先 source 密钥文件再 exec：

    ~/.config/systemd/user/xmatrix-daemon.service.d/10-secrets-env.conf
    [Service]
    ExecStart=
    ExecStart=/bin/bash -c 'set -a; . "$HOME/.common_shell_setup_local.sh"; set +a; exec "$HOME/.local/bin/xmatrix" daemon'

密钥仍只存在 `~/.common_shell_setup_local.sh` 一处（不额外落盘）。`xmatrix setup daemon` 会重写
主单元，drop-in 不受影响；改完需要 `scripts/xmatrix-daemon-secrets.sh --restart` 让 daemon 换环境。

**这条路走不通，别试**：`xmatrix agent add ... --runtime <wrapper>` 对 harness run 无效
（用 `--runtime /bin/echo` 做探针，run 仍然启动 omp）。

**备选**：`EnvironmentFile=<生成的文件>` 等价，但密钥会多一份明文落盘，故用 ExecStart 覆盖；
`omp login <provider>` 把 key 存进 vault，与 env 无关，但每台机器要重新登录；
`xmatrix secret` 是 Hub 侧密钥目录，只给 `xmatrix secret exec` 用，不会自动注入 harness 环境。

## 降级链与角色

`modelRoles` 解析模型；`retry.fallbackChains` 给每个 key 配一条降级链。查当前值：
`omp config get modelRoles`、`omp config get retry.fallbackChains`。

链 key 的解析顺序（`resolveRetryFallbackChainKey`）：

1. 精确模型 key（`<provider>/<modelId>`）
2. `provider/*` 通配 key
3. 角色名
4. `default`

`retry.fallbackOn` 默认 `any`（401/429/5xx 都触发）。没有单独配链的角色共用 `default`。
**链上每一跳的窗口都要够大**：从大窗口模型掉到 200K 兜底的发现值，会把已经很长的一轮撑爆。

**副作用（omp 行为）**：降级成功的那一轮会把结果持久化——`config.yml` 的 `modelRoles.default`
被改写成降级目标，同一次写盘还删掉 `enabledModels` 里已不在目录中的条目。配额耗尽跑过一次之后，
要回头检查这两个 key 是否还指向本意；显式 `--model` 的调用不改文件。这也是本文不抄值的理由。

## 压缩

`compaction` 段决定「什么时候压缩、压缩后留多少原文」：

| key | 含义 |
|---|---|
| `compaction.thresholdPercent` | 触发线 = 窗口 × 该百分比 |
| `compaction.keepRecentTokens` | 压缩后保留多少原文 |
| `compaction.reserveTokens` | 触发线以下留给一次回复的余量 |

算法在 `@oh-my-pi/pi-agent-core/compaction`（`resolveThresholdTokens` /
`resolveBudgetReserveTokens` / `prepareCompaction`）。保留上限 = 恢复带（触发线 × 0.8）减预留，
所以 `keepRecentTokens` 只在足够大的窗口上生效，小窗口会被自动夹紧。写死百分比是让口径与窗口
解耦，换模型时触发线按比例走；不写时 omp 用「窗口 − 15% 预留」，在百万窗口上与 85% 只差 1 token。
保留下来的原文越多，压缩后上下文越大、下一次压缩越早，但每轮输入 token 也更多——这是取舍。

## Thinking 级别（effort）

解析优先级（源码 `resolveThinkingLevelForModel`）：

1. 会话显式级别：`--thinking <level>`，或模型选择器/`modelRoles` 值里的 `:<level>` 后缀。
2. 模型定义里的 `thinking.defaultLevel`：`models.yml` 自声明，或目录内置。
3. 全局 `defaultThinkingLevel`（值见 `omp/config.yml`）。

要点：

- `auto` **只能**出现在第 1、3 层。模型定义与 `modelOverrides` 的 `defaultLevel` 只接受
  `minimal|low|medium|high|xhigh|max`；写 `auto` 会让**整个 `models.yml` 加载失败**、该
  provider 的模型全部消失（`Model "x" not found`），而 `omp models list` 仍返回 0——容易误判。
- `auto` 是逐轮分类器：按请求挑档位，上限由 `providers.autoThinkingMaxEffort`（默认 `xhigh`）
  决定。
- 目录内置的 `defaultLevel` **压过**全局 `defaultThinkingLevel`。这类模型只能用第 1 层改成
  auto：角色后缀 `:auto` 或 `--thinking auto`。
- 查生效档位：会话 JSONL 里的 `thinking_level_change` 记录
  （`~/.omp/agent/sessions/<cwd>/…jsonl`），`configured:"auto"` 表示 auto 已启用，
  `thinkingLevel` 是该轮实际档位。

## Gemini（Antigravity）要单独的出口节点

网关侧走 antigravity 凭证（`/opt/cliproxyapi/auth/antigravity-*.json`），上游是
`daily-cloudcode-pa.googleapis.com`。这条上游有区域闸门：出口 IP 不受支持时回
`400 invalid_request_error: User location is not supported for the API use.`。

所以网关（`/etc/mihomo/config.yaml`）给 Cloud Code 单独一个出口组，其余流量仍走默认出口：

    proxy-groups:
      - name: GOOGLE-AI
        type: select
        use: [subscription]
        filter: "美国AI解锁1"
    rules:
      - DOMAIN-SUFFIX,cloudcode-pa.googleapis.com,GOOGLE-AI
      - DOMAIN-SUFFIX,cloudcode-pa.sandbox.googleapis.com,GOOGLE-AI
      - DOMAIN,daily-cloudcode-pa.googleapis.com,GOOGLE-AI
      - DOMAIN,daily-cloudcode-pa.sandbox.googleapis.com,GOOGLE-AI

`daily-cloudcode-pa.googleapis.com` 必须写成 `DOMAIN`：它**不是**
`cloudcode-pa.googleapis.com` 的子域（标签边界），`DOMAIN-SUFFIX` 不匹配，会静默落到
`MATCH,PROXY` 又走默认出口。`journalctl -u mihomo` 里 `match ... using` 可验证——
命中打印 `match Domain(daily-cloudcode-pa.googleapis.com) using GOOGLE-AI[...]`。

生效顺序：改完 `sudo systemctl restart mihomo`（`PUT /configs?force=true` 热载实测未生效），
再 `sudo systemctl restart cliproxyapi`——CPA 按凭证持有 HTTP/1.1 长连接池，不重启会继续
复用旧出口的连接。CPA 重启后 antigravity 模型表要等一轮 `fetchAvailableModels` 探测才回来，
其间 `unknown provider for model gemini-4-argon-*` 是中间态，不是配置错。

其余 provider 不受影响，仍走默认出口。

## Skills

omp 读 `~/.agents/skills`（`skills.enableAgentsUser`）和 `~/.omp/agent/skills`
（`skills.enablePiUser`，native user 级）以及项目级目录；`enableClaudeUser` /
`enableCodexUser` 保持 `false`，否则会和 `~/.agents/skills` 重名。目录布局见仓库根
`AGENTS.md` 与 `docs/REPO_GUIDE.md`。

- 共享 skill（repo `skills/`）由 `scripts/sync-skills.py` 链进 `~/.agents/skills`，omp 原生可见。
- omp 专属 skill 放 repo `omp/skills/<name>/`，同一脚本链进 `~/.omp/agent/skills`：`toil-offloading-omp`、`herdr-desktop`、`herdr-coordinator`、`omp-tui-extension-authoring`、`omp-tui-extension-ux`、`skill-creator`。用途读各自的 `SKILL.md`。
- `skill-creator` 是 Anthropic 官方 plugin 的 omp 副本（Apache-2.0，随包带 `LICENSE.txt`）。
  上游把评测脚本写死成 `claude -p`；本地抽到
  `omp/skills/skill-creator/scripts/harness.py`，默认调 `omp -p`，
  `SKILL_CREATOR_CLI=claude` 或 `--cli claude` 才回退上游行为。升级时重新解包上游，覆盖
  `SKILL.md`/`agents`/`assets`/`eval-viewer`/`references`/其余脚本，只保留本地 `harness.py`
  及调用它的改动。

omp 的 loader 只扫一层，对每个「目录或软链接」条目探测 `<entry>/SKILL.md`，不递归、不读裸
`*.md`；所以视图里每个 skill 都必须是一个目录条目（脚本已保证，嵌套 bundle 会被拍平）。

## Subagent 档位（`modelRoles.task`）

omp 的 `task` 工具带一个内建 `task` agent，它的 frontmatter 是 `model: "@task"`，展开到
`modelRoles.task`：没配就落到当前会话模型；配了就统一换成该角色。值是
`<provider>/<modelId>[:<level>]`，查值用 `omp config get modelRoles.task`。

- 只改 `config.yml` 这一处。`tasks[].model` 或自定义 agent frontmatter 里再钉模型，就会出现
  第二个真相源，而且会静默覆盖本角色。
- 例外要显式：某个 slice 常规档做不了（跨文件诊断、独立 review）时，在那一个 task 上写
  `model`，并在 contract 里说明原因。
- `sonic` 走 `@smol`、`scout` 是只读 agent——它们是 agent，不是更便宜的模型；用之前确认它们
  解析到谁。
- 并发/嵌套上限由 `task.maxConcurrency` / `task.maxRecursionDepth` 决定（默认 32 / 2，准确值用
  `omp config get task`）；`task.batch` 默认开，所以独立 slice 要在**一次** `task` 调用的
  `tasks[]` 里并发抛。
- 编排规则（合同写法、分区、验收、收尾）的正文在共享 skill `skills/toil-offloading/`
  （`SKILL.md` + `references/assignment-brief.md`）；omp 侧的运行入口是
  `omp/skills/toil-offloading-omp/`，Codex 侧是 `codex/skills/toil-offloading-codex/`
  + `codex/agents/{dspix,glmpix}.toml` 那套原生 team。

## herdr worker 档位（`modelRoles.worker` / `modelRoles.reviewer`）

`herdr-coordinator` 用 `hc run ... omp --model worker` 起后台 worker。模型不写在 skill 里，
取这两个角色，所以换模型只改 `config.yml` 一处。

- 角色名走 `modelRoles` 解析，`--model worker` 与 `--model task`、其他角色同一条路径；冒号后
  的档位写在角色值里，启动命令不带 `--thinking`。
- `reviewer` 要与 `worker` 不同家族：审查的价值来自独立第二意见，同模型审自己的实现容易点头。
- 降级链会静默换模型（`retry.fallbackChains`），所以 skill 要求派任务后按 nonce 读 worker 会话
  jsonl 里的 `provider/model` 复核，不能只信启动参数。
- worker 自己起 subagent / task 不受限制；协调者只管合同范围与验收。

## 扩展：`/deepen`

`~/.omp/agent/extensions/` 是本机真目录（herdr 集成、`pi-fff.json` 也在里面），所以只链接单个
文件，不链接整个目录。omp 直接加载该目录下的 `*.ts`。

`/deepen` 把一句话需求**旁路加深**成可执行、可验收的提示词，再回填输入框：

1. 两种入口共用一个内部函数：`/deepen [deep|quick|spec] [提示词…]`（无参数时回落到输入框），
   或在输入框里写好草稿后按 **alt+e**。
2. 直连便宜的 `deepseek-flash`（`POST https://api.deepseek.com/chat/completions`，OpenAI
   兼容），凭据取环境变量 `DEEPSEEK_API_KEY`。不走会话模型：加深是「写作」，固定便宜模型更
   可预测，也省掉 agent 的系统提示词与工具定义。
3. **非阻塞**：请求期间不换输入框、不锁键盘，进度只写状态栏
   （`🔍 deepening (deep · deepseek-flash) 7s · alt+shift+e cancel`）。
   取消入口是 **alt+shift+e** 或 `/deepen cancel`，两者 abort 同一个 `AbortController`；
   120 秒超时与 `session_shutdown` 也走同一条 abort。
4. 回填前比对 `getEditorText()`：草稿没变才写回（`success`）；变了就进 `draft-changed`，
   结果暂存不覆盖，按 alt+e 或 `/deepen apply` 才取回。失败、取消、缺凭据一律不动输入框。
5. 模型输出按不可信处理：剥掉整段 Markdown 围栏、空结果报错、不要求任何标签协议。
6. 只在交互式 TUI 可用；print/RPC/JSON 模式没有输入框可回填，会写日志并给出明确告警。

状态机：`idle → running → {success | failure | cancel | draft-changed}`，另有 `headless`。
`/deepen config` 打印当前生效配置与所处状态。

配置文件 `~/.omp/agent/extensions/deepen.json`（可选，路径可用 `OMP_DEEPEN_CONFIG` 覆盖；
坏字段逐项退回默认并在运行时提示；内置默认值定义在 `omp/extensions/deepen.ts`）：

    {
      "style": "deep",                    // deep | quick | spec，也可用 /deepen style 选并落盘
      "model": "deepseek/deepseek-flash", // <provider>/<id>，直连只取 / 后面的 wire id
      "baseUrl": "https://api.deepseek.com",
      "apiKeyEnv": "DEEPSEEK_API_KEY",
      "maxTokens": 8192,
      "system": "…"                       // 整体替换内置风格提示词
    }

「备用模型」通道：配置指向的模型请求失败（HTTP 错 / 无内容 / 空结果）时，自动改用内置默认
三元组重试一次，成功后状态栏与 notify 标 `(fallback)`。缺凭据**不**退备用——备用可能用另一个
环境变量的 key，静默换凭据会掩盖配置错误。

## Plugins（插件）

插件本体**不入库**。`~/.omp/plugins/` 是运行时状态：`bun install` 会重写 `package.json`
与 `bun.lock`，omp 会就地重写 `omp-plugins.lock.json`，`node_modules/` 还有上百个包。

仓库只跟踪**清单** `omp/plugins.txt`（每行一个 `omp plugin install` spec，`#` 注释说明每个
插件的作用）与三份配置种子；缺失项由安装钩子补齐：

| repo 文件 | 作用 |
|---|---|
| `omp/plugins.txt` | 插件清单与逐个说明；`npm:` 前缀、版本后缀、`[features]` 括号、`github:user/repo[#ref]` 这类 git spec 均可 |
| `omp/pi-fff-features.json` | pi-fff 的 feature 状态种子（关掉 `autocomplete`），由 seed 钩子拷到 `~/.omp/agent/extensions/pi-fff.json` |
| `pi/herdr-agents/config.json` | pi-herdr-agents（pi 侧）的配置种子，同上拷到 `~/.pi/agent/herdr-agents/config.json` |
| `omp/herdr-agents/config.json` | omp-herdr-agents 的配置种子，同上拷到 `~/.omp/agent/herdr-agents/config.json` |
| `scripts/omp-plugins.sh` | `./install` 的 Phase 2 对比 `omp plugin list --json`，只安装缺失的插件 |

要点：

- **只在 `./install` 跑**，不进 15 分钟的 `sync.sh`：安装需要网络和 `bun`。
- **bun 是硬前置**：omp 的插件安装器 spawn `bun install`（按名字查 PATH）。`./install` 的
  Phase 2 会先装 bun；脚本自己也按 `PATH` → `$BUN_INSTALL/bin` → `~/.bun/bin` →
  Homebrew/`/usr/local` 的顺序解析，并把所在目录前置进 `PATH`。都没有时只告警跳过（外部依赖
  缺失不算安装失败）。
- **不能放 `post-install.d/`**：那批钩子在 Phase 1（纯本地）跑，早于 bun/omp 的网络安装，
  会以 "omp not on PATH" 跳过，或在 bun 缺失时让 omp 抛
  `Executable not found in $PATH: "bun"`。
- 已安装的插件**不重装**。重复 `omp plugin install` 不是空操作：它会重新解析包，并把 feature
  选择重置回 manifest 默认值。
- npm spec、**git spec**（`github:user/repo[#ref]`、`https://…/repo.git[#ref]`、`git+ssh://…`）与
  **本地路径**都支持；路径用于尚未发布的 fork（判断是否已装看目录名），git spec 的判重名取仓库名
  （omp 装完的插件名来自仓库 `package.json` 的 `name`，与仓库名一致）。
- **`omp-herdr-agents` 的三条硬条件**（`subagent` 工具注册成功 ≠ 能启动）：
  1. 必须在 Herdr 里启动 omp（`HERDR_ENV=1`），且 `herdr` 在 PATH。窗口外工具照常注册，
     启动时才报不可用。
  2. 会话必须落盘：`omp -p --no-session` 没有 session 文件可交给子 agent，启动直接失败；
     headless 父进程退出时子窗格一并被关掉，所以结果投递要交互式会话。
  3. omp 必须 ≥ 18.6：扩展用到 `@oh-my-pi/pi-ai` 的 `getSupportedThinkingLevels` 导出，
     更低的版本在扩展校验阶段就失败。该包声明的 `skills/` 由 omp 自动加载（含启动/监督/
     取消/worktree 的操作指南）。
- 子 agent 是 omp 进程，配置/角色路径全部走 omp：`~/.omp/agent/herdr-agents/config.json`、
  `~/.omp/agent/agents`、`<cwd>/.omp/agents`；不传 `model` 时继承父会话选择器，种子里钉的
  默认值在 `omp/herdr-agents/config.json`。
- feature 状态文件是 `~/.omp/agent/extensions/pi-fff.json`：omp 的 `getAgentDir()` 兼容 shim
  解析到 `~/.omp/agent`（放 `~/.pi/agent/extensions/` 无效）。仓库用
  `omp/pi-fff-features.json` 做种子，由 `scripts/post-install.d/10-seed-configs.sh` 在目标缺失
  时拷入（已存在则不覆盖，保留你在会话里的选择）。

加插件：把 spec 写进 `omp/plugins.txt`，再跑 `bash scripts/omp-plugins.sh`（或 `./install`）。

## 状态栏（`statusLine`）

`config.yml` 的 `statusLine` 定左侧/右侧 segment；查值 `omp config get statusLine`，预览单个
segment 用 `omp gallery --surface=segment --segment=<name>`。

右侧用了 `session` 段（**session id 前 8 位**），便于就地读出 `omp --fork <前缀>` /
`--resume <前缀>` 要用的 id。session id 是「epoch 毫秒的 16 进制」，`session` 段只截前 8 位 =
毫秒 >> 16，所以**同一 ~65 秒窗口内启动的会话共享前缀**；`--fork`/`--resume` 用前缀匹配到多个时
会静默按「最新优先」取第一个，拿不准就用不带参数的 `--resume` 选择器。

## 硬性约束

### 1. `config.yml` 必须可写

omp 会对 config.yml 上 native file lock，只读符号链接或只读 store 文件会导致每次启动报
`Failed to acquire native file lock … Permission denied`。repo 里的 `omp/config.yml`
保持**普通可写文件**（当前权限 `600`），omp 的原子写会保留 symlink target。

### 2. `config.yml` 不支持注释

`omp config set/reset` 重写文件时会按纯 YAML 重新序列化并**剥离注释**。所以说明性文字一律放
本 README 或 `AGENTS.md`，不要写进 `config.yml`。`models.yml` / `WATCHDOG.yml` 没有这类重写
路径，注释可以留。

### 3. 不要存密钥：一律写 key 引用

`auth.*` / provider token / broker 凭据等敏感信息**绝不入库**。`models.yml` 与
`gateways-login.json` 的 `apiKey` 都先过 omp 的 `resolveConfigValue()`
（`src/config/resolve-config-value.ts`），三种取值按顺序判断：

1. 以 `!` 开头 → 用 `/bin/sh -c` 执行，取 stdout（10s 超时，成功缓存，失败 30s 退避）
2. 整串是一个**精确匹配的环境变量名**（`$envExact`）→ 读该环境变量
3. 都不是 → 当**字面量**用

所以入库只写第 1 种：

    providers:
      <name>:
        apiKey: "!grep -m1 '^export <VAR>=' $HOME/.common_shell_setup_local.sh | cut -d= -f2- | tr -d '\"'"

真值只存在未入库的 `~/.common_shell_setup_local.sh` 一处（那里是双引号赋值，所以要 `tr -d '"'`）。

**为什么不能写环境变量名**：变量未设置时第 2 条返回 `undefined`，omp 落到第 3 条，把变量名本身
当 key 发出去 → 网关 401（`The API key format is incorrect` /
`Please carry the API secret key in the 'X-Api-Key' field`）。而 omp 常被不 source 该文件的进程
拉起：herdr 的 pane 来自 systemd --user 的 transient unit，xmatrix daemon 只带单元里那点环境，
这些进程里没有 `*_API_KEY`。命令引用由 omp 自己执行，所以任何启动路径都取得到 key，密钥仍只在
一个文件里。

`gateways-login.json` 走同一套规则（插件把引用原样交给 omp，不自己解析）。会话内 `/login`
直接粘贴明文 key 时，插件会改存为已存在该 key 的环境变量名；它提示
「Nothing sets X, so omp sends that name itself as the key.」就是这个陷阱。网关 provider 不吃
omp vault，只能用引用。

YAML 引号：`tr -d '"'` 处在双引号标量里，必须写成 `tr -d '\""'"`。少写末尾那个 `'`，YAML 仍能
解析，但 shell 串引号不闭合，omp 只表现为 `No API key found for <provider>`。改完用下面这条验证
（去掉环境变量才是 herdr pane 的真实条件）：

    env -u <VAR> omp -p --no-session --mode=json --model <provider>/<model> "reply ok"

密钥在磁盘上也要密文时，把命令换成解密器即可：`!gpg -q -d <file>`、`!pass show <entry>`、
`!op read <ref>`。命令必须非交互（omp 用隔离 stdio 跑它，弹 tty 提示会挂住）。

### 4. 用户级 `AGENTS.md` 会遮蔽其他工具的用户级上下文

`~/.omp/agent/AGENTS.md` 是 native provider（优先级 100）的用户级上下文文件。它存在时，omp 只保留这一个用户级上下文文件，`~/.claude/CLAUDE.md`、`~/.codex/AGENTS.md`、`~/.gemini/GEMINI.md`、`~/.copilot/copilot-instructions.md`、`~/.agents/AGENTS.md` 都不再进入会话（claude/codex/gemini 用户源本身还需 `enabledProviders` 才启用）。项目级上下文按目录深度各留一个，不受影响。

`RULES.md` 只认 native 位置（本目录，以及项目最近的 `.omp/`）。它是 always-apply 常驻规则：正文随**每次请求**携带，长会话被压缩后仍然生效，因此必须保持很短；与 `AGENTS.md` 内容重复时会被去重。细则放 `omp/skills/toil-offloading-omp/SKILL.md`，用 `skill://toil-offloading-omp` 读。

## 常用命令

    omp config list                  # 查看所有 key + 当前/默认值
    omp config set   <key> <value>   # 设置并持久化到 config.yml（写透 symlink）
    omp config get   <key>           # 读取
    omp config reset <key>           # 恢复默认
    omp config path                  # 打印 agent 配置目录 (~/.omp/agent)
    omp models list                  # 确认 models.yml 生效
    omp --advisor                    # 启用 WATCHDOG.yml 里的 advisor

`config` 的 key 是**扁平**格式：`omp config set theme.dark titanium` 对应嵌套
`theme: { dark: titanium }`。只写入被覆盖的 key，其余 deep-merge 默认值。

## 可选：纳入更多静态配置

若想跟踪 agents / skills / hooks，可用 `omp agents unpack`（默认写到
`~/.omp/agent/agents`）后软链接对应子目录。当前按需再补。

新增静态配置时记得同步三处：repo 文件、两个 dotbot 配置（`install.conf.yaml` 与
`sync.conf.yaml`）的 link 段、本 README 的表格。
