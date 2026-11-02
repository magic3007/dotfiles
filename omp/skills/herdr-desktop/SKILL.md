---
name: herdr-desktop
description: 在 omp 主会话里用 hc 启动、分发、等待、读回 omp 后台 worker（Opus/Astra），核实实际模型，放进 Herdr 侧边栏并清理
---

# herdr-desktop：用 hc 协调 omp 后台 worker

主对话留在当前 omp 会话。后台 worker 全部用 `hc`（herdr-core 0.1.16）管理。不要让用户去 Herdr 终端里操作。
所有命令已于 2026-11-02 在本机实测通过（worker t1j=Astra、t1k=Opus，主会话 t6）。下文的 `t6` 换成你主会话的 `$HC_TERMINAL_ID`。

## 硬约束

- agent harness 只用 omp。不要安装或启动 Claude Code CLI、Codex CLI。
- 模型只按下表启动。不支持或缺失时停下告诉用户，不要悄悄换模型或档位。
- 换 provider（如 Astra 换到其它 provider）前必须先告诉用户。

| 角色 | 启动命令 |
|---|---|
| Opus | `omp --model mafia/claude-opus-5-5 --thinking xhigh` |
| Astra | `omp --model kafara/gpt-6-astra --thinking xhigh` |

## 0. 前置检查

```sh
which omp hc            # herdr-app 在本机不在 PATH 上；窗口在用户桌面，经 herdr-core connect 连入
hc server status        # 看 core/holder 存活；不要 stop/restart 用户的 core
omp models list 2>&1 | awk '/^mafia /,/└/'  | grep -E '│ claude-opus-5-5 '
omp models list 2>&1 | awk '/^kafara /,/└/' | grep -E '│ gpt-6-astra '
# thinking 列必须含 xhigh
hc templates            # 当前为 {"templates":[]}，无现成模板，直接起 omp
```

`omp models list` 按 provider 分段输出；必须在对应 provider 段内确认，别的段同名不算。

## 1. 放进 Herdr 侧边栏（同一 space）

无 `herdr.space` 标签的 worker 在 Herdr 里隐藏。取主会话所在 space：

```sh
SPACE=$(hc get "$HC_TERMINAL_ID" | python3 -c 'import json,sys; print(json.load(sys.stdin)["labels"].get("herdr.space",""))')
```

只给 `herdr.space` 不给 `herdr.tab` 时，Herdr 在该 space 新建一个 tab（实测 `where` 变成 `frontcs2 / 2`、`/ 3`）。Herdr 收编后 terminal 会带 `keep:true`，`hc kill` 仍然是终结。

## 2. 启动

```sh
hc run --bg --name probe-astra --cwd /abs/project --label herdr.space=$SPACE \
  omp --model kafara/gpt-6-astra --thinking xhigh
hc run --bg --name probe-opus  --cwd /abs/project --label herdr.space=$SPACE \
  omp --model mafia/claude-opus-5-5 --thinking xhigh
```

- 必须 `--bg`、`--name`、显式 `--cwd`。worker 默认随父终端结束。
- 就绪：`hc wait <name>` 返回 `"status":"idle"`。实测 Opus 返回 idle 时屏幕还空白，所以再 `hc read --lines 15 <name>`，看到状态栏里的模型名与 `xhi` 再发任务。
- 屏幕上出现信任/确认提示（status `blocked`）时：停下告诉用户，不要 `hc keys` 代确认。本机 omp 首启未出现此提示。

## 3. 分发任务

```sh
hc send probe-astra "只读任务（nonce: ASTRA-7f3c）。…约束：禁止修改、创建或删除任何文件；禁止启动 subagent、task 或任何其它 agent。完成后执行：hc send t6 '<回复>'。回复第一行必须是：FROM=<你的 HC_TERMINAL_ID> NONCE=ASTRA-7f3c MODEL=<模型>。卡住时也用 hc send t6 说明原因。"
```

- `t6` 写主会话地址字面值（先 `echo $HC_TERMINAL_ID`）。worker 的 `$HC_TERMINAL_ID` 是它自己的地址，不能让它回报给自己。
- 每个 worker 用不同 nonce：用来证明任务送达、回复来自该 worker，并在第 5 步定位它的会话文件。
- `send` 返回 `{"started":true,...}` 即送达。

## 4. 等待与读回

```sh
hc wait --children all --timeout 900   # 任一 worker 回报时以 reason:"message" 提前返回
hc wait probe-astra --timeout 900      # 只等一个
```

- 不要 sleep 轮询。`reason:"message"` 时报告作为下一条输入到达，形如 `<hc from="t1k probe-opus">…</hc>`；处理后再等其余 worker。`reason:"timeout"` 只是检查点，继续等。
- 在 omp 里跑超过 60s 的 `hc wait` 会转后台 job，用 `wait` 工具接结果。
- 核对：报告标签 `from` 与第一行 `FROM=`/`NONCE=` 都对得上；再 `hc read --lines 80 <name>` 确认 worker 屏幕上有派发的 `<hc from="t6">` 原文。

## 5. 确认实际模型（不要只信启动参数）

omp 遇到 400/429 可能静默回退。读 worker 会话 jsonl 里 assistant 消息的 provider/model。状态栏短 id 是 UUIDv7 时间前缀，同一分钟启动的 worker 短 id 相同（实测都是 01a19b93），不能用来区分。按"第一条 user 消息含 nonce"定位（排除派发方自己的会话）：

```sh
python3 - ASTRA-7f3c 120 <<'PY'
import json,sys,glob,os,time,collections
nonce=sys.argv[1]; mins=float(sys.argv[2])
for f in glob.glob(os.path.expanduser('~/.omp/agent/sessions/**/*.jsonl'),recursive=True):
    if time.time()-os.path.getmtime(f)>mins*60: continue
    first=None; c=collections.Counter()
    for l in open(f):
        o=json.loads(l); m=o.get('message') or {}
        if m.get('role')=='user' and first is None: first=json.dumps(m.get('content'),ensure_ascii=False)
        if o.get('type')=='model_change': c['model_change '+str(o.get('model'))]+=1
        if m.get('role')=='assistant': c[f"assistant {m.get('provider')}/{m.get('model')}"]+=1
    if first and nonce in first: print(f); print('  ',dict(c))
PY
```

期望：只有一个 `model_change` 且所有 `assistant` 都是指定 provider/model（实测 `kafara/gpt-6-astra` ×9、`mafia/claude-opus-5-5` ×7）。出现第二个 model_change 或别的 provider 时告诉用户。会话目录按 cwd 命名，例 `~/.omp/agent/sessions/-projects-frontcs2/`。

## 6. 清理

```sh
hc kill probe-astra && hc kill probe-opus   # 返回 state:finished, reason:killed, exit_code 129
hc rm t1j && hc rm t1k                      # 返回 {"removed":"t1j"}；用 address
hc ls --all                                 # 确认已不在列表
```

只清理自己启动的 terminal。`hc ls` 会列出用户的其它在跑会话。
