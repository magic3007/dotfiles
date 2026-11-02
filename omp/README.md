# omp (Stencil / oh-my-pi) — dotfiles 配置

`omp` 是一个 **AI coding agent harness**（不是提示符主题工具！不要和 Oh My Posh 混淆）。

- 官网: https://omp.sh
- npm/bun 包: `@oh-my-pi/pi-coding-agent`
- 安装: `curl -fsSL https://omp.sh/install | sh`。两种落点：**有 bun**（≥1.4.4，架构匹配）时走
  `bun install -g`，产物是 `~/.bun/bin/omp`（`#!/usr/bin/env bun` shim）；**没有 bun** 时退化为
  下载预编译 ELF，直接写 `~/.local/bin/omp`（`PI_INSTALL_DIR` 的默认值）。
- 版本: omp/18.15.0（本机 `omp --version` 与 npm 上的最新版一致）。低于 18.6 的 omp 装不了
  `omp-herdr-agents` 3.5.0：扩展会报
  `Export named 'getSupportedThinkingLevels' not found in module 'omp-legacy-pi-bundled:@oh-my-pi/pi-ai'`。

## 软链接

本目录下的**六个静态配置**和 `extensions/` 下的文件被 `install.conf.yaml` 软链接进 `~/.omp/agent/`：

| repo 文件 | 软链接到 | 作用 |
|---|---|---|
| `omp/config.yml` | `~/.omp/agent/config.yml` | 全局设置：模型角色、fallback 链、压缩、状态栏 |
| `omp/models.yml` | `~/.omp/agent/models.yml` | 自定义 provider / 模型定义 |
| `omp/gateways-login.json` | `~/.omp/agent/gateways-login.json` | `omp-model-gateway` 插件的网关清单（key 写引用，见第 3 节） |
| `omp/WATCHDOG.yml` | `~/.omp/agent/WATCHDOG.yml` | advisor（`--advisor`）的 reviewer 花名册 |
| `omp/AGENTS.md` | `~/.omp/agent/AGENTS.md` | 用户级上下文文件：回复风格（ASD-STE100 + 中文） |
| `omp/RULES.md` | `~/.omp/agent/RULES.md` | always-apply 常驻规则：同一句回复风格，长会话压缩后仍生效 |

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
`force` 帮你省掉的只是这一步的报错，旧文件仍会丢：

    mv ~/.local/bin/omp ~/.wastebasket/omp-$(omp --version | tr / -)-elf
    curl -fsSL https://omp.sh/install | sh      # 有 bun 时产出 ~/.bun/bin/omp
    ./install --only link                       # 建 ~/.local/bin/omp 软链

不要改用「改单元 PATH」的办法：`xmatrix setup daemon` 会用固定列表重写单元，覆盖手改；
软链不受影响，也不用重启 daemon。改完 `xmatrix harness refresh`，用
`xmatrix harness status <harness:id>` 看结果。

同源问题（本机未链）：`claude`、`gemini`（在 `~/.nvm/versions/node/*/bin`）、
`kimi`（`~/.kimi-code/bin`）、`opencode`（`~/.opencode/bin`）同样不在 daemon PATH 里，
Hub 侧也报 missing。

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

### Gateway provider（`gateways-login.json`）

目录里没有、也不是手写 `models.yml` 的第三类 provider：**网关**。`omp-model-gateway` 插件把
`~/.omp/agent/gateways-login.json` 里每个网关注册成一个 provider（本机：`mafia`、`kafara`），
字段是 `name` / `baseUrl` / `api` / `apiKey` / `extraModels`。
该文件已入库（软链接，见上表）：`apiKey` 写的是 **key 引用**而非密钥（第 3 节），
插件存引用、omp 解析，所以文件里不含密钥。新增/修改走会话内 `/login` 的 gateway 入口
（输入环境变量名或 `!命令` 即可；直接粘贴明文 key 时，若该 key 已存在于某个环境变量，
插件会改存那个变量名并说明）。模型清单由 `GET <baseUrl>/v1/models` 发现，再并上
`extraModels` 的静态 id，所以 `omp models list` 的条数基本等于发现结果。

**火山引擎不走网关**：账号是 Ark Coding Plan，`GET /api/coding/v1/models` 回 38 个模型
（deepseek、doubao、glm 都在内），而本机只用 Kimi-K3.1-Pro。所以 `volcengine` 已从
`gateways-login.json` 删掉，改成 `models.yml` 里的静态 provider，只声明
`kimi-k3.1-pro`（Ark 的 alias id，实发可用；带日期的 `kimi-k3-1-pro-261024` 是同一个模型）。
效果：`omp models volcengine` 只剩 1 条，`--model volcengine/deepseek-v4-1-flash-260910`
直接 `Model ... not found`。直连内置 `deepseek/` provider（默认模型的降级链）不受影响。

手改该文件后执行 `omp models refresh` 让模型缓存重新拉取。

本机网关与手写 provider 的 `apiKey` 用的是 **`!命令` 引用**，不是环境变量名：

    !grep -m1 '^export MAFIA_API_KEY=' $HOME/.common_shell_setup_local.sh | cut -d= -f2- | tr -d '"'

原因：xmatrix 通过它的 daemon 拉起 omp，daemon 只带 systemd 单元里那点环境，
**没有** `~/.common_shell_setup_local.sh` 里的 `*_API_KEY`。而引用解析规则是
「`!命令` 取 stdout → 环境变量名取该变量 → 其余当字面量」，环境变量不存在时
**会把变量名本身当 key 发出去**，火山引擎于是回
`401 AuthenticationError: The API key format is incorrect`（早期 `volcengine` 的 apiKey 写的是
环境变量名 `VE_CODE_API_KEY`，在 daemon 拉起的环境里必然复现）。
换成命令引用后，daemon 拉起的 omp 也能取到 key，密钥仍只存在
`~/.common_shell_setup_local.sh` 一处（那里是双引号赋值，所以命令里要 `tr -d '"'`）。
命令引用按进程缓存，改 key 后需要新进程才生效。

仍未覆盖：**内置目录 provider**（`deepseek` 等）的 key 只能来自环境变量（目录定义，不是本文件），
所以 xmatrix run 里 `retry.fallbackChains.default` 的 `deepseek/deepseek-flash` 取不到 key，
降级链在 xmatrix 场景下是死的。下一节给通用做法。

### xmatrix agent run 的凭据：给所有模型/harness 的做法

xmatrix 的 daemon 子进程环境 = daemon env + `XMATRIX_*`（看 `/proc/<run pid>/environ`）。
**没有下面那个 drop-in 时**，daemon 环境里没有任何 `*_API_KEY`，于是凭据只来自环境变量的
provider 全部失败：

| harness | 凭据来源 | xmatrix run 里 |
|---|---|---|
| omp 网关（mafia/kafara） | `gateways-login.json` 的 key 引用 | 已改 `!命令` 引用，可用 |
| omp 手写 provider（volcengine） | `models.yml` 的 key 引用 | 同上（`!命令` 引用） |
| omp 内置目录 provider（deepseek/zai/kimi/openrouter…） | 环境变量 | 无 drop-in 时变量名被当 key 发出 → 401 |
| codex 自定义 provider | `config.toml` 的 `env_key = "DEEPSEEK_API_KEY"` 等 | 同上 |
| codex 官方 / claude / gemini | 文件式（`~/.codex/auth.json`、`~/.claude/.credentials.json`、`~/.gemini/*`） | 可用（不依赖 env） |
| omp vault（`omp login` 存过的 provider） | omp 自己的凭据库 | 可用，实测 `env -i` 下 `omp token devin/kimi-code` 仍可取 |

**做法**：给 daemon 的环境注入密钥。`scripts/xmatrix-daemon-secrets.sh`
（`./install` 与 15 分钟 sync 都会跑）写一个 systemd drop-in：

    ~/.config/systemd/user/xmatrix-daemon.service.d/10-secrets-env.conf
    [Service]
    ExecStart=
    ExecStart=/bin/bash -c 'set -a; . "$HOME/.common_shell_setup_local.sh"; set +a; exec /home/yanzhou/.local/bin/xmatrix daemon'

daemon 先 source 密钥文件再 exec，于是 daemon 环境带着全部 key，agent run 继承。
密钥仍只存在 `~/.common_shell_setup_local.sh` 一处（不额外落盘）。
`xmatrix setup daemon` 会重写主单元，drop-in 不受影响；改完需要
`scripts/xmatrix-daemon-secrets.sh --restart` 让 daemon 换环境。

实测（2026-10-19，xmatrix 1.0.587）：daemon `/proc/<pid>/environ` 22 个 key 变量，
取值与 shell 完全一致；新 spawn 的 run 子进程 21 个；火山 429（额度用尽）后
`retry.fallbackChains.default` 真的切到 `deepseek/deepseek-flash` 并完成该轮
（此前降级链因缺 key 是死的）。

**这条路走不通，别试**：`xmatrix agent add ... --runtime <wrapper>` 对 harness run 无效。
用 `--runtime /bin/echo` 做探针，run 仍然启动 omp（`✓ Oh My Pi ACP serve backend ready`），
`xmatrix agent show` 也不回显 runtime。

**备选**：

- harness 原生凭据库：omp 用 `omp login <provider>`（或会话内 `/login`）把 key 存进
  vault，与 env 无关，实测 `env -i` 下 `omp token devin/kimi-code` 可取；缺点是每台机器
  要重新登录，网关 provider 不吃 vault（仍是 `!命令` 引用）。
- `EnvironmentFile=<生成的文件>`：等价，但密钥会多一份明文落盘，故本仓库用 ExecStart 覆盖。
- 不要用 `xmatrix secret` 解决模型凭据：它是 Hub 侧密钥目录，只给 agent run 提供
  `xmatrix secret exec`（自己包命令），不会自动注入 harness 环境。

因此默认模型 `volcengine/kimi-k3.1-pro` 依赖两个前提：`models.yml` 里的 `volcengine` 块在、
key 取得到（`VE_CODE_API_KEY`）。`enabledModels` 里也要有
`volcengine/kimi-k3.1-pro`（白名单语义同上）。这条不再依赖 `omp-model-gateway` 插件。

注意 `--profile <name>` 会把插件目录也隔离：profile 下 `omp plugin list` 是空的，
网关 provider（`mafia`/`kafara`）与其模型都不存在；`models.yml` 与 profile 的配置文件也不共用，
所以 `volcengine` 块同样不在。要在 profile 里复现这套配置，得先在该 profile 装插件、
重建 `gateways-login.json`，并补上 `models.yml` 的 `volcengine` 块。

默认模型由 `modelRoles.default` 决定（本机 `minimax-test/MiniMax-M78:auto`，1M 窗口）。
MiniMax-M78 有两个入口，窗口不同：

| 入口 | 窗口 | 凭据 | 本机用法 |
|---|---|---|---|
| `minimax-test/MiniMax-M78` | 1M | `!命令` 读 `MINIMAX_MY_API_KEY` | `default` / `minimax-pro` / `task` 走这里 |
| `mafia/MiniMax-M78` | 200K（插件兜底值） | `!命令` 读 `MAFIA_API_KEY` | 不再是默认；只有降级链才会用到 |

`modelRoles` 里的自定义角色名（`devin-opus` 等）只是别名，不参与默认解析。

**provider key 一律写 `!命令`，不写环境变量名**。`minimax-test`、`mafia`、`kafara`
（`models.yml` 与 `gateways-login.json` 两处）、`volcengine` 都是这条：

```yaml
apiKey: "!grep -m1 '^export MINIMAX_MY_API_KEY=' $HOME/.common_shell_setup_local.sh | cut -d= -f2- | tr -d '\"'"
```

真值仍只在未入库的 `~/.common_shell_setup_local.sh` 里，命令只是去那里取。为什么不能
写环境变量名：omp 的 `resolveConfigValue()` 顺序是 `!命令` → 环境变量名 → 字面量，
**环境变量缺失时它把变量名本身当 key 发出去**。而 herdr 起的 pane 恰好就缺这些
export——`herdr-core` 是 systemd --user 的 transient unit（`hc-serve-<hash>.service`），
环境来自 systemd --user manager，不 source `~/.common_shell_setup.sh`，manager 自己
也没有这些 key。2026-11-02 的故障链（session `01a19bfc`，herdr worktree
`frontcs2-wt/review`）：主模型 `kafara/gpt-6-astra` 撞 `429 usage_limit_reached` →
降级到 `minimax-test/MiniMax-M78` → 网关回
`401 login fail: Please carry the API secret key in the 'X-Api-Key' field` →
再降 `MiniMax-M3.1-Flash` 同样 401 → 整条 fallback 链断掉。同一时刻别的会话（环境
里有 export）用同一个 key 是 200 的，所以不是 key 失效，是那份进程环境里没有它。
`!命令` 由 omp 用 `/bin/sh -c` 执行（10s 超时、成功缓存、失败 30s 退避），因此
herdr pane、systemd unit、xmatrix daemon 拉起的 omp 都取得到 key。
上游现在 `Authorization: Bearer` 与 `X-Api-Key` 两种头都收（2026-11-02 实测各只发一种
都是 200），所以 `models.yml` 里不再手写 `headers.X-Api-Key`。

改这条命令时注意 YAML 引号：`tr -d '"'` 处在双引号标量里，必须写成 `tr -d '\""'"`。
少写末尾那个 `'`，YAML 仍能解析，但解出来的 shell 串引号不闭合，`/bin/sh` 报
`Syntax error: Unterminated quoted string`，omp 侧只表现为
`No API key found for <provider>`，看不出是配置写错。改完用
`env -u <VAR> omp -p --no-session --mode=json --model <provider>/<model> "reply ok"`
验证（去掉环境变量才是 herdr pane 的真实条件）。

**网关真 id**：flash 模型的真 id 是 `MiniMax-M3.1-Flash`（点号），点号写法虽不在
`GET /v1/models` 列表里，但网关照样接受并回显 `MiniMax-M3.1-Flash`。横杠写法
`MiniMax-3.1-Flash` 不是上游 id：网关把它模糊匹配到 `MiniMax-M3`，响应里的 `model`
字段回显 `MiniMax-M3`，跑的根本不是 flash 模型，所以不再声明。`MiniMax-M3` 同样不再
声明。`models.yml` 里 `minimax-test` 只留 `MiniMax-M78` 与 `MiniMax-M3.1-Flash`
两个 id，`MiniMax-M3.1-Flash-Preview` 与 `MiniMax-M3` 都不出现。`smol` 角色指
`minimax-test/MiniMax-M3.1-Flash`。

**窗口是实测的**（2026-11-02 直连本网关发 prompt）：`MiniMax-M78` /
`MiniMax-M3.1-Flash` 两个模型，950,205 与 1,010,205 token 的 prompt 都回 200，
1,040,000 token 被上游回
`529 overloaded_error`，边界与 1048576 一致；网关 `/v1/models` 不带 `token_limits`，
所以 `contextWindow: 1048576` 只能手写。上游的 `max_tokens` 参数校验上限是 524288
（`does not support max tokens > 524288`），那是参数上限不是生成上限，`models.yml` 里
仍取 65536。

默认模型的降级另有精确 key `minimax-test/MiniMax-M78`（本机
`- minimax-test/MiniMax-M3.1-Flash → - deepseek/deepseek-flash`），
两级都是 1M 窗口：中途掉到 200K 窗口的模型（mafia/kafara 的兜底值）会把已经很长的一轮撑爆。
`retry.fallbackChains.default`（本机 `- deepseek/deepseek-flash`）是其余角色共用的兜底：
`default` 角色自己的链就是这条，其他没有单独配置链的角色也复用同一条。链路解析按
「精确模型 key → `provider/*` 通配 key → 角色名 → `default`」定 key（源码
`resolveRetryFallbackChainKey`），所以默认模型失败时（401/429/5xx 等，`retry.fallbackOn`
默认 `any`）会自动切到 `deepseek/deepseek-flash` 重试。实测：给默认模型一个坏 key，
一轮内即 `switched model; retried` 并由 `deepseek/deepseek-flash` 完成该轮。

**副作用（实测，2026-10-28）**：降级成功的那一轮会把这个结论持久化——`omp/config.yml` 里的
`modelRoles.default` 被改写成降级目标（`volcengine/kimi-k3.1-pro:auto` →
`deepseek/deepseek-flash`），同一次写盘还把 `enabledModels` 里已不在目录中的条目一并删掉。
所以火山引擎配额耗尽（Ark 回 `429 AccountQuotaExceeded`）跑过一次之后，回头要检查
`enabledModels` 与 `modelRoles.default` 是否还指向 Kimi。显式 `--model` 的调用不改文件。

本机另行给 Claude 类 provider 配了统一降级链 `mafia → devin → kafara`：

| chain key | 顺序 |
|---|---|
| `minimax-test/MiniMax-M78` | `minimax-test/MiniMax-M3.1-Flash` → `deepseek/deepseek-flash`（都是 1M 窗口） |
| `mafia/*` | `devin/claude-opus-5-5` → `kafara/devin/claude-opus-5-5` |
| `devin/*` | `kafara/devin/claude-opus-5-5` |
| `default` | `deepseek/deepseek-flash`（未单独配链的角色共用这条兜底） |

`kafara/devin/claude-opus-5-5` 是 `ai.kafara.men` 发现结果里的 id 原样（网关 `GET /v1/models`
返回的 `id` 是反转串 = 混淆，插件解出可读 id 并存进 `models.db` 的 `model_cache`），实测
`POST /v1/messages` 直发该 id 与 `omp -p --model kafara/devin/claude-opus-5-5` 均 200。
注意 `devin/claude-opus-5-5` 与 `mafia/claude-opus-5-5` 在 omp 默认编码系统提示下会被上游按
ToS 拒答（`stopReason: error`），此时正是链尾 kafara 接手。

kafara 与 mafia 一样不声明窗口（`/v1/models` 只回 `id/object/created/owned_by`，没有
`token_limits`），发现结果一律落到插件兜底 200000/64000。所以 `models.yml` 里照 `mafia` 块
的写法补了 `kafara` 块，把链上用到的 `devin/claude-opus-5-5`、`claude-opus-5-5-high`
（kafara 原生 id，固定 high 档）和 `devin/claude-fable-5-1` 钉成 1M，thinking 档位
`low…max`，值取自内置目录 anthropic 的同名模型。覆盖按 **provider+id** 生效，kafara 其余
~90 个发现模型仍是 200000/64000。

按需删掉的 provider：`devin-cliproxy`（本机 127.0.0.1:30288 的 CLIProxyAPI）已从
`models.yml` 与 `enabledModels` 移除；`cliproxy-yanzhou.service` 仍在跑，供其他客户端使用。

### 1M 窗口的压缩口径

`compaction` 段决定「什么时候压缩、压缩后留多少原文」。本机按 1M 窗口（默认模型
`minimax-test/MiniMax-M78`）写：

| 设置 | 值 | 含义 |
|---|---|---|
| `compaction.thresholdPercent` | 85 | 触发线 = 窗口 × 85%，1M → 891,289 token |
| `compaction.keepRecentTokens` | 400000 | 压缩后保留多少原文 |
| `compaction.reserveTokens` | 20480 | 触发线以下留给一次回复的余量 |

算法在 `@oh-my-pi/pi-agent-core/compaction`（`resolveThresholdTokens` /
`resolveBudgetReserveTokens` / `prepareCompaction`），本机实测值：

| 窗口 | 触发线 | 保留上限（自动夹紧后） |
|---|---|---|
| 1,048,576（`minimax-test/*`） | 891,289 | 400,000 |
| 272,000（`devin/gpt-6-1-sol` 等） | 231,200 | 164,480 |
| 200,000（mafia/kafara 兜底值） | 170,000 | 115,520 |

保留上限 = 恢复带（触发线 × 0.8）减预留，所以 `keepRecentTokens` 写 400000 只对 1M
窗口生效：200K 窗口的模型被夹到 115,520，与改动前一致。

不写 `thresholdPercent` 时 omp 用「窗口 − 15% 预留」，在 1M 上与 85% 只差 1 token；
写死百分比是让口径与窗口解耦，换模型时触发线按比例走。

代价：保留的原文越多，压缩后剩下的上下文越大，下一次压缩来得更早，但每轮输入 token
也更多。`keepRecentTokens` 从 150000 提到 400000 是「少丢细节、多花 token」的取舍。

### Gemini（Antigravity）要单独的出口节点

`gvomp`（`omp --model kafara/gemini-4-argon-high`）在网关侧走 antigravity 凭证
（`/opt/cliproxyapi/auth/antigravity-*.json`），上游是
`daily-cloudcode-pa.googleapis.com`。这条上游有区域闸门：出口 IP 不受支持时回
`400 invalid_request_error: User location is not supported for the API use.`。

实测（2026-10-16，同一账号、同一客户端，各 8~20 次）：

| 网关出口 | 成功 |
|---|---|
| 家宽 `208.214.194.162`（原 `PROXY` 默认） | 5/8 |
| 美国 AI 解锁 `88.210.37.226` | 20/20 |

所以问题在出口 IP，不在 omp。网关（my_gcp `/etc/mihomo/config.yaml`）加了一个只服务
Cloud Code 的组，其余流量仍走家宽出口：

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
`MATCH,PROXY` 又走家宽出口。`journalctl -u mihomo` 里 `match ... using` 可验证——
命中打印 `match Domain(daily-cloudcode-pa.googleapis.com) using GOOGLE-AI[...]`。

生效顺序：改完 `sudo systemctl restart mihomo`（`PUT /configs?force=true` 热载实测未生效），
再 `sudo systemctl restart cliproxyapi`——CPA 按凭证持有 HTTP/1.1 长连接池，不重启会继续
复用旧出口的连接。CPA 重启后 antigravity 模型表要等一轮 `fetchAvailableModels` 探测才回来，
其间 `unknown provider for model gemini-4-argon-*` 是中间态，不是配置错。

其余 provider（Devin、xAI、Claude）不受影响，仍出家宽出口：`curl -x
http://127.0.0.1:7890 https://ipinfo.io/ip` 回 `208.214.194.162`。

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
- omp 专属 skill 放 repo `omp/skills/<name>/`，同一脚本链进 `~/.omp/agent/skills`。当前有
  `toil-offloading-omp`（委派工作给 subagent 的编排规则，见下节）和 `herdr-desktop`
  （主会话用 `hc` 启动、分发、等待、读回 omp 后台 worker，核实实际模型，放进 Herdr 侧边栏），以及
  `herdr-coordinator`（协调者工作流：本会话规划/集成/终审，Opus worker 在独立 worktree 实现，
  Astra worker 独立审查，命令沿用 `herdr-desktop`）。
- `skill-creator`（`omp/skills/skill-creator/`）是 Anthropic 官方 plugin
  `claude-plugins-official/plugins/skill-creator` 的 omp 副本（Apache-2.0，随包带
  `LICENSE.txt`）。上游把评测脚本写死成 `claude -p`；这里抽到 `scripts/harness.py`，
  默认调 `omp -p`，`SKILL_CREATOR_CLI=claude` 或 `--cli claude` 才回退上游行为。
  临时探针 skill 造在 `<cwd>/.omp/skills/`（omp 的 `native:project` 目录），用完即删。
  升级方式：重新解包上游 plugin，覆盖 `SKILL.md`/`agents`/`assets`/`eval-viewer`/
  `references`/其余脚本，只保留本地这个 `harness.py` 及三处调用它的改动。

omp 的 loader 只扫一层，对每个「目录或软链接」条目探测 `<entry>/SKILL.md`，不递归、
不读裸 `*.md`；所以视图里每个 skill 都必须是一个目录条目（脚本已保证，嵌套 bundle
会被拍平）。完整布局见仓库根 `AGENTS.md` 的 Skills 一节。

## Subagent 档位（`modelRoles.task`）

omp 的 `task` 工具带一个内建 `task` agent，它的 frontmatter 是 `model: "@task"`。角色别名展开走
`modelRoles.task`：没配就落到当前会话模型（root 用什么，subagent 就用什么）；配了就统一换成廉价档。
本机配置：

    modelRoles:
      task: minimax-test/MiniMax-M78:auto           # subagent 执行档；root 用 default 做判断

- 只改这一处。`tasks[].model` 或自定义 agent frontmatter 里再钉模型，就会出现第二个真相源，
  而且会静默覆盖本角色。
- 例外要显式：某个 slice 常规档做不了（跨文件诊断、独立 review）时，在那一个 task 上写
  `model`，并在 contract 里说明原因。
- `sonic` 走 `@smol`、`scout` 是只读 agent——它们是 agent，不是更便宜的模型；用之前确认
  它们解析到谁（当前 `smol` = `minimax-test/MiniMax-M3.1-Flash:auto`，实测 `scout` 也落这一档）。
- 并发/嵌套上限：`task.maxConcurrency` 32（超出排队）、`task.maxRecursionDepth` 2。
  `task.batch` 默认开，所以独立 slice 要在**一次** `task` 调用的 `tasks[]` 里并发抛。
- 编排规则（合同写法、分区、验收、收尾）在 `omp/skills/toil-offloading-omp/SKILL.md`，对应 Codex
  侧 `codex/skills/toil-offloading/` + `codex/agents/{dspix,glmpix}.toml` 那套原生 team。

## herdr worker 档位（`modelRoles.worker` / `modelRoles.reviewer`）

`herdr-coordinator` 用 `hc run ... omp --model worker` 起后台 worker。模型不写在 skill 里，
取这两个角色，所以换模型只改 `config.yml` 一处：

    modelRoles:
      worker: minimax-test/MiniMax-M78:xhigh      # 实现、调试、修测试
      reviewer: deepseek/deepseek-flash:max        # 独立审查、第二意见

- 角色名走 `modelRoles` 解析，`--model worker` 与 `--model task`、`--model mafia-opus` 同一条路径；
  冒号后的档位写在角色值里，启动命令不带 `--thinking`。
- `reviewer` 故意选与 `worker` 不同家族：审查的价值来自独立第二意见，同模型审自己的实现容易点头。
  2026-11-02 实测 `devin/*` 周配额耗尽、`mafia/claude-opus-5-5` 走降级链回落到 minimax-test，
  所以 reviewer 落在 deepseek；该模型档位只有 low/high/max，没有 xhigh。
- 降级链会静默换模型（`retry.fallbackChains`），所以 skill 要求派任务后按 nonce 读 worker 会话
  jsonl 里的 `provider/model` 复核，不能只信启动参数。
- worker 自己起 subagent / task 不受限制；协调者只管合同范围与验收。

## Plugins（插件）

插件本体**不入库**。`~/.omp/plugins/` 是运行时状态：`bun install` 会重写 `package.json`
与 `bun.lock`，omp 会就地重写 `omp-plugins.lock.json`，`node_modules/` 还有上百个包。

仓库只跟踪**清单**，缺失项由安装钩子补齐：

| repo 文件 | 作用 |
|---|---|
| `omp/plugins.txt` | 每行一个 `omp plugin install` spec（`npm:` 前缀、版本后缀、`[features]` 括号均可）；空行与 `#` 注释忽略 |
| `omp/pi-fff-features.json` | pi-fff 的 feature 状态种子（关掉 `autocomplete`），由下面的 seed 钩子拷到 `~/.omp/agent/extensions/pi-fff.json` |
| `pi/herdr-agents/config.json` | pi-herdr-agents（pi 侧）的配置种子（`models.default` 等），同上由 seed 钩子拷到 `~/.pi/agent/herdr-agents/config.json` |
| `omp/herdr-agents/config.json` | omp-herdr-agents 的配置种子，同上由 seed 钩子拷到 `~/.omp/agent/herdr-agents/config.json` |
| `scripts/omp-plugins.sh` | `./install` 的 Phase 2 对比 `omp plugin list --json`，只安装缺失的插件 |

要点：

- **只在 `./install` 跑**，不进 15 分钟的 `sync.sh`：安装需要网络和 `bun`。
- **bun 是硬前置**：omp 的插件安装器 spawn `bun install`（按名字查 PATH）。`./install` 的
  Phase 2 会先装 bun（`command -v bun` 与 `~/.bun/bin/bun` 都缺失时）；
  脚本自己也按 `PATH` → `$BUN_INSTALL/bin` → `~/.bun/bin` → Homebrew/`/usr/local` 的顺序解析，
  并把所在目录前置进 `PATH`。都没有时只告警跳过（外部依赖缺失不算安装失败）。
- **不能放 `post-install.d/`**：那批钩子在 Phase 1（纯本地）跑，早于 bun/omp 的网络安装，
  会以 "omp not on PATH" 跳过，或在 bun 缺失时让 omp 抛
  `Executable not found in $PATH: "bun"`。
- 已安装的插件**不重装**。重复 `omp plugin install` 不是空操作：它会重新解析包，并把 feature
  选择重置回 manifest 默认值。
- npm spec 与**本地路径**都支持；路径用于尚未发布的 fork（判断是否已装看目录名）。git spec 告警跳过。
- 当前清单：`npm:pi-fff`（FFF 模糊查找、内容搜索；默认**覆盖内建 `read`/`grep`**，用会话内
  `/fff-features` 开关）、`npm:omp-model-gateway`（`/login` 的 gateway 入口；本机 `mafia`、
  `kafara` 两个 provider 来自它；`volcengine` 已改为 `models.yml` 静态 provider——见
  「Gateway provider」一节）、
  `npm:omp-herdr-agents`（**本地 fork 发布的包**：异步 subagent，每个子 agent 是 Herdr
  窗格里的 **omp** 进程；工具 `subagent`/`subagent_send`/`worktree_*` 等；条件与限制见下；
  源码在 `~/projects/omp-herdr-agents`，未发布时可直接写该路径）。上游 `pi-herdr-agents`
  仍留在 pi 侧（`pi/settings.json`），两者互不干扰。
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
- **`omp-herdr-agents` 的三条硬条件**（`subagent` 工具注册成功 ≠ 能启动）：
  1. 必须在 Herdr 里启动 omp（`HERDR_ENV=1`），且 `herdr` 在 PATH。窗口外工具照常注册，
     启动时才报不可用。
  2. 会话必须落盘：`omp -p --no-session` 没有 session 文件可交给子 agent，启动直接失败；
     headless 父进程退出时子窗格一并被关掉，所以结果投递要交互式会话。
  3. 该包声明的 `skills/` 会被 omp 自动加载（会话里出现 `omp-herdr-agents` 技能，含
     启动/监督/取消/worktree 的操作指南）。
- **子 agent 是 omp，fork 直接实现，不再打补丁**。fork 在 `~/projects/omp-herdr-agents`
  （上游 `giuseppecrj/pi-herdr-agents` 的 omp 专用分支），关键机制：
  1. 子进程 `omp -r <会话文件> --hook … --model … --thinking … '<task>'`。omp 只接管
     **已存在**的会话文件，所以父进程在启动前一定先写 header（`fork`/`lineage` 再拷父会话
     的历史行）；`--system-prompt*` 仍传文件路径（omp 对不含换行的参数先按文件读）。
  2. 子进程结束判据是 `agent_end` 且没带 `willContinue`（omp 没有 `agent_settled`，重试/
     换模型/压缩续跑都带该标记），并跳过还有排队消息的结束；不再轮询 20 秒。
  3. 回报的模型取自子会话 assistant 消息自带的 `provider`/`model`（omp 每条都写），
     `model_change` 只作兜底，所以 `Model used` 不再显示父模型。
  4. 思考档位来自宿主的 `thinking.efforts`（`low`…`max`），不再被压成 `off`。
  5. 子 agent 会**正常加载宿主**，因此角色允许时能再开子 agent（嵌套按代理深度限制）。
  6. 命令名避开 omp 内建：worktree 命令是 `/subagent-worktree`（omp 已占 `/worktree`，
     扩展命令同名会被静默跳过）；续跑提示是 `omp -r <file>`。
  配置/角色路径全部走 omp：`~/.omp/agent/herdr-agents/config.json`、`~/.omp/agent/agents`、
  `<cwd>/.omp/agents`。
- 模型选择：不给 `model` 时子 agent 继承父会话选择器（同样是 omp，所以 `volcengine/…` 也有效）；
  `models.default` 种子固定为 `deepseek/deepseek-flash`，避免默认烧贵模型。

加插件：把 spec 写进 `omp/plugins.txt`，再跑 `bash scripts/omp-plugins.sh`
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

所以入库写法是**只写引用**。本机统一用第 1 条（`!命令` 去未入库的 secrets 文件里取值）：

    providers:
      mafia:
        apiKey: "!grep -m1 '^export MAFIA_API_KEY=' $HOME/.common_shell_setup_local.sh | cut -d= -f2- | tr -d '\"'"

`gateways-login.json` 的 `apiKey` 走**同一套规则**（omp-model-gateway 插件把引用原样交给
omp，不自己解析），所以入库写法同样是引用：

    { "name": "kafara", "baseUrl": "https://ai.kafara.men",
      "api": "anthropic-messages",
      "apiKey": "!grep -m1 '^export KAFARA_API_KEY=' $HOME/.common_shell_setup_local.sh | cut -d= -f2- | tr -d '\"'",
      "extraModels": [] }

只写环境变量名（`apiKey: MAFIA_API_KEY`）也能工作，但**只在那个 export 真的在进程环境里
时**。⚠️ 变量未设置时 `$envExact` 返回 `undefined`，omp 落到第 3 条，把字面量
`MAFIA_API_KEY` 当 key 发出去 → 网关 401。herdr pane 就是这种环境（见上文
「provider key 一律写 `!命令`」），所以本机不再用变量名写法。
（`omp-model-gateway` 插件在登录时会提示这种情况：「Nothing sets X, so omp sends that name
itself as the key.」）

密钥在磁盘上也要密文的话，把命令换成解密器即可：

    "apiKey": "!gpg -q -d ~/.omp/keys/kafara.gpg"     # 或 !pass show llm/kafara、!op read op://…

命令必须非交互：omp 用隔离 stdio 跑它，`gpg`/`pass` 不能弹 tty 提示（gpg-agent 已缓存
口令，或口令来自 `--passphrase-file`）。`~/.common_shell_setup_local.sh` 不入库，所以
密钥不跟仓库走。

### 4. 用户级 `AGENTS.md` 会遮蔽其他工具的用户级上下文

`~/.omp/agent/AGENTS.md` 是 native provider（优先级 100）的用户级上下文文件。它存在时，omp 只保留这一个用户级上下文文件，`~/.claude/CLAUDE.md`、`~/.codex/AGENTS.md`、`~/.gemini/GEMINI.md`、`~/.copilot/copilot-instructions.md`、`~/.agents/AGENTS.md` 都不再进入会话（claude/codex/gemini 用户源本身还需 `enabledProviders` 才启用）。项目级上下文按目录深度各留一个，不受影响。

`RULES.md` 只认 native 位置（本目录，以及项目最近的 `.omp/`）。它是 always-apply 常驻规则：正文随**每次请求**携带，长会话被压缩后仍然生效，因此必须保持很短；与 `AGENTS.md` 内容重复时会被去重。

当前 `RULES.md` = 回复风格一行 + 委派硬规则（`task` 并发抛 `tasks[]`、subagent 默认档 `modelRoles.task`、禁止 `bash`/CLI 冒充 worker、禁止重叠写入）。硬规则只留**可判定**的条目，合同写法、路由、验收这些细则放在
`omp/skills/toil-offloading-omp/SKILL.md`，按需用 `skill://toil-offloading-omp` 读，避免每次请求重复付费。

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
