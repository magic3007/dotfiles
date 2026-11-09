---
name: omp-tui-extension-ux
description: "Designing an omp TUI extension that reads/refills the composer, adds a shortcut, or shows progress: pick non-blocking UI, cover the state machine, and word the authoring prompt so the API surface is enumerated first. Companion to omp-tui-extension-authoring (mechanics: package, typecheck, tmux smoke)."
---

# omp TUI 扩展：交互设计契约

用于「用户手动触发」的 omp 扩展：润色/改写草稿、生成候选、摘要、任何要回填输入框的功能。

分工：
- 本文管**交互形态与状态覆盖**（为什么会被一个示例带偏、漏掉哪些状态）。
- `omp-tui-extension-authoring` 管机制：打包、类型检查、tmux 真机验证。

## 1. 第一步永远是枚举 API 面

不要从示例倒推能力。先读已安装包的类型定义：

```bash
ls ~/.bun/install/global/node_modules/@oh-my-pi/pi-coding-agent/dist/types/index.d.ts
# ExtensionUIContext 里至少包含：
#   select / notify / setStatus / getEditorText / setEditorText / supportsEditor / custom
# ExtensionContext 里至少包含：
#   ui / model / modelRegistry / runEphemeralTurn? / sessionManager
```

判断依据：

| 需求 | 正确 API | 错误做法 |
|---|---|---|
| 显示运行中 | `ctx.ui.setStatus(key, text)` | 用 `ui.custom` 卡片占屏 |
| 让用户选一项 | `ctx.ui.select(title, options)` | 让用户背参数 |
| 读当前草稿 | `ctx.ui.getEditorText()` | 要求用户把草稿写进命令参数 |
| 回填草稿 | `ctx.ui.setEditorText(text)` | 直接发消息给会话 |
| 判断能否编辑 | `ctx.ui.supportsEditor === false` 时警告 | 只查 `ctx.hasUI` |
| 一次不进会话的 LLM 调用 | `ctx.runEphemeralTurn(...)`（可选路径） | `import @oh-my-pi/pi-ai` 的 `completeSimple` |

**单看一个示例会把方案锁死在那个示例的形态上。** `examples/hooks/qna.ts` 用 `ui.custom`，因为它要一个问答面板；它不代表“显示进度”就该占屏。

## 2. 交互形态：默认非阻塞

| 形态 | 适用 | 代价 |
|---|---|---|
| 非阻塞：状态栏 + 原地回填 | 默认；短请求（1–30 s）；用户还要读/改草稿 | 需要处理“草稿被改” |
| 阻塞：`ui.custom` 非 overlay 卡片 | 必须独占输入；请求长到你确定用户不该打字 | 用户看不见草稿；容易顺手覆盖输入 |

规则：

- 进度只写状态栏，键要唯一（如 `prompt-polish`），结束时 `setStatus(key, undefined)`。
- 阻塞卡片只在“输入必须冻结”时用。用就配 `AbortSignal.any([loader.signal, AbortSignal.timeout(ms)])`，Esc 才有取消。
- 非阻塞时，**回填前必须比对** `ctx.ui.getEditorText() !== draft`；不一致就丢弃结果并提示，不覆盖。
- 失败和取消**绝不** `setEditorText` 恢复原文；原草稿本来就没被动过。

## 3. 入口矩阵：两种都要

slash command 会消费整行输入。所以：

| 用户手里的文本 | 入口 |
|---|---|
| 已在输入框 | `pi.registerShortcut("ctrl+alt+p", { handler })` |
| 现敲/带参数 | `pi.registerCommand("x", { handler: (args, ctx) => … })` |

两者共用一个内部函数，参数 `explicitText?: string` 区分来源：

```ts
const fromEditor = explicitText === undefined;
const draft = fromEditor ? ctx.ui.getEditorText() : explicitText;
// 命令无草稿时回落到输入框，而不是报“没有内容”
```

选项用 `getArgumentCompletions` 补全 + `select` 兜底；`select()` 只回 `label` 字符串，label 必须能反查回业务键。

选快捷键前查冲突：

```bash
grep -rn "defaultKeys" ~/.bun/install/global/node_modules/@oh-my-pi/pi-tui/src/{app-keybindings,keybindings}.ts
```

## 4. 先写状态机，再写代码

每个状态都要有可观测行为。缺一个就是交互漏洞：

| 状态 | 行为 |
|---|---|
| idle | 正常输入 |
| running | 状态栏显示进度 + 用的模型/选项；重复触发给提示，不并发 |
| success | 回填 + 一行 notify |
| failure | notify 错误；草稿不动 |
| cancel | 静默或轻提示；草稿不动；abort 分支可达 |
| 草稿被改 | 丢弃结果 + 提示 |
| 空草稿 | 提示怎么给内容 |
| headless / 无编辑区 | 明确警告，不静默 |
| 缺凭据 / 配置坏 | 报缺哪个环境变量；配置解析失败回默认值 |

`AbortController` 建了但没有触发入口 = 死代码。写完代码搜一次 `abort`。

## 5. 输出按不可信处理

- 剥 Markdown 围栏：只在首尾行是 ``` 时剥，正文里的围栏保留。
- 空结果视为错误，不要回填空字符串。
- 避免“必须匹配的标签协议”（如 `<enhanced_prompt>` 正则），模型一不守格式就整次失败。
- 结构化输出优先用短约束 + 兜底，而不是强协议。

## 6. 模型与成本

- 默认不要用会话模型。会话可能挂着贵模型，而润色/摘要用便宜模型就够。
- 直连 OpenAI 兼容端点时手写 `fetch`；omp 没把 pi-ai 的 `streamSimple` 暴露给扩展。`import @oh-my-pi/pi-ai` 会让 bun 在插件目录再装一份，与宿主版本脱节。
- 可配置项：`model` / `baseUrl` / `apiKeyEnv` / `maxTokens` / 默认选项 / `system`。配置路径支持环境变量覆盖，坏配置回默认。
- `ctx.runEphemeralTurn` 适合“想复用会话凭据但不进 transcript”的场景；注意 `tools: false` 可能被某些 transport 拒绝，要降级重试，`dedupeReply: false` 防止重复行被去重。

## 7. 验收

真机，不用单测代替：

```bash
tmux new-session -d -s smoke -x 120 -y 40 "cd /tmp && omp --extension /path/to/ext.ts"
sleep 20
tmux send-keys -t smoke "draft text" ; tmux send-keys -t smoke C-a ...   # 触发快捷键/命令
tmux capture-pane -p -t smoke | tail -12
tmux kill-session -t smoke
```

三条路径：正常、备用模型/配置路径、缺凭据报错。最后用已安装插件再跑一次。

## 8. 反模式（真实案例）

`dotfiles` 的 `/deepen`（`872eb01:omp/extensions/deepen.ts`，后由 `ab16701` 删除）是反面教材：

- 只学了 `ui.custom` + `BorderedLoader`，于是运行中整块占屏，草稿被遮住。
- `/deepen` 只吃参数，不回落输入框，必须记 Alt+E。
- 唯一选项、唯一模型、无配置，输出用强标签协议解析。
- 有 Esc 取消（优点），但没有状态栏，重复触发静默返回。

`omp-prompt-polish`（`extension/prompt-polish.ts`）是正面参照：`setStatus` 非阻塞、命令回落、四风格、配置化、失败不覆盖；仍未做取消入口。

## 9. prompt 模板

```text
给 omp 写一个 TUI 扩展：<功能>。

第一步：读 @oh-my-pi/pi-coding-agent 的 dist/types/index.d.ts，
列出 ExtensionAPI 与 ExtensionUIContext 的全部方法，再设计。
只用公开 API；不 import @oh-my-pi/pi-ai 或 pi-tui 子路径。

交互约束：
- 非阻塞：运行中不得遮挡、锁定输入框；进度只写状态栏。
- 失败/取消绝不覆盖用户输入；回填前比对 getEditorText()。
- 必须有取消入口，AbortController 接到键位，不留死代码。
- headless 模式给明确警告。

入口：slash command + 快捷键，共用一个内部函数，
用 explicitText 区分来源；命令无参数时回落输入框。

先列状态机：idle/running/success/failure/cancel/草稿被改/headless。

模型：默认便宜模型直连，key 走环境变量；可配置
model/baseUrl/apiKeyEnv/maxTokens/默认选项/system；坏配置回默认。

输出按不可信处理：剥围栏、空结果报错、不用硬标签协议。

选项要可发现：参数补全 + 选择器。

验收：tmux 起真 TUI 跑三条路径（正常、备用模型、缺凭据）。

打包成 npm 包，package.json 里写 omp.extensions 清单。
```
