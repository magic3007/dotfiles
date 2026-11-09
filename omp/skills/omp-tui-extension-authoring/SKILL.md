---
name: omp-tui-extension-authoring
description: "Author, typecheck, install and真机验证 an omp (oh-my-pi) TUI extension — slash command + shortcut, side LLM turn or direct fetch, plugin packaging and tmux smoke test"
---

# omp TUI 扩展：写、装、验

适用于给 omp 加一个「用户手动触发」的功能（slash command / 快捷键 / 编辑器回填），或把别的 harness 的插件移植过来。

## 1. 定位 API（不要猜）

omp 的扩展类型定义在已安装包里，直接读源码：

```bash
ls ~/.bun/install/global/node_modules/@oh-my-pi/pi-coding-agent/
# 类型总入口：src/extensibility/extensions/types.ts
#   ExtensionAPI（约 1795 行起）：registerCommand / registerShortcut / registerTool / exec / events
#   ExtensionUIContext（约 316 行起）：select / notify / setStatus / getEditorText / setEditorText / supportsEditor
#   ExtensionContext（约 748 行起）：ui / models / runEphemeralTurn? / sessionManager / setInterval…
```

现成样例：`examples/extensions/*.ts`（`api-demo.ts` 最小骨架，`plan-mode.ts` 有命令 + 快捷键）。

关键判断：
- **要发 LLM 请求** → `ctx.runEphemeralTurn()`（见下）。没有别的官方 one-shot 通道。
- **要读写输入框** → `ctx.ui.getEditorText()` / `setEditorText()`。
- **要固定模型 + 固定 key** → 手写 `fetch` 打 OpenAI 兼容端点；omp 未把 pi-ai 的 `streamSimple` 暴露给扩展。

## 2. 旁路 LLM 调用

```ts
const { replyText } = await ctx.runEphemeralTurn({
  promptText,                 // 指令 + 素材放这里；system prompt 是会话的那份（走 prompt 缓存）
  tools: false,               // 不带工具定义；Cursor 等强制原生工具的 transport 会拒绝 → 降级重试一次
  dedupeReply: false,         // 默认 true 会去重重复行并截到 4 KiB，代码/prompt 类内容必须关掉
  minimizeEffort: true,
  maxTokens: cfg.maxTokens,   // 部分 transport 拒绝调用方输出上限，不确定就别传
  signal,
});
```

结果**不进会话历史**，所以适合「润色 / 生成候选 / 摘要」这类不该污染 agent 上下文的功能。

## 3. 入口形态：一个都不能少

slash command 会**消费整行输入**，所以：

| 用户想做的事 | 正确入口 |
|---|---|
| 处理「已经在输入框里」的文本 | `pi.registerShortcut("ctrl+alt+p", …)` |
| 处理「现敲」的文本 | `pi.registerCommand("x", { handler: (args, ctx) => … })`，文本写在参数里 |

两者共用同一个内部函数，用一个 `explicitText?: string` 参数区分来源；只有「来自输入框」那条路需要在回填前比对 `getEditorText() !== draft`（期间用户可能继续打字，此时丢弃结果而不是覆盖）。

选快捷键前先查默认键位是否冲突：

```bash
grep -rn "defaultKeys" ~/.bun/install/global/node_modules/@oh-my-pi/pi-tui/src/{app-keybindings,keybindings}.ts
```

`select()` 只回传 **label 字符串**，所以 label 必须是能反查回业务键的值。

## 4. 打包与安装

```json
{ "name": "…", "version": "0.1.0", "type": "module",
  "omp": { "extensions": ["extension"] } }
```

三种装法：`omp plugin install github:user/repo`（git spec 可用）、`omp plugin install <本地路径>`、或把 `.ts` 软链进 `~/.omp/agent/extensions/`。

更新已装插件用 `omp plugin upgrade <name>`（**没有** `omp plugin update`）。

## 5. 类型检查（对 shipped types，别对 src）

对 `src/index.ts` 跑 tsc 会淹没在 omp 自身的报错里；指向 `dist/types/index.d.ts`：

```json
{ "compilerOptions": { "target": "ES2023", "lib": ["ES2023","DOM"], "module": "ESNext",
    "moduleResolution": "bundler", "strict": true, "noEmit": true, "skipLibCheck": true,
    "types": ["node"],
    "paths": { "@oh-my-pi/pi-coding-agent": ["<HOME>/.bun/install/global/node_modules/@oh-my-pi/pi-coding-agent/dist/types/index.d.ts"] } },
  "include": ["<repo>/extension/**/*.ts"] }
```

（tsconfig 放仓库外的临时目录，别把绝对路径提交进去；`bun add -d @types/node` 后 `bunx tsc -p tsconfig.json`。）

## 6. 真机验证（tmux）

```bash
tmux new-session -d -s smoke -x 120 -y 40 "cd /tmp && omp --extension /path/to/ext.ts"
sleep 20                                   # 等 TUI 起来
tmux send-keys -t smoke "/cmd arg" Enter
sleep 10..25 && tmux capture-pane -p -t smoke | grep -v '^$' | tail -12
```

坑：
- **`ctrl+u` 清不掉 omp 输入框** → 草稿会连同新输入一起被当 prompt 提交，真的起一个 agent turn。清空用 `ctrl+c`，中断 turn 用 `Escape`。
- 每次跑完 `tmux kill-session -t smoke`。
- 三条路径都要验：正常路径、配置里的备用路径（如 `"model": "session"`）、缺凭据的报错路径（`env -u API_KEY omp …`）。
- 最后再用**已安装插件**（不带 `--extension`）跑一次，确认打包/清单没问题。
