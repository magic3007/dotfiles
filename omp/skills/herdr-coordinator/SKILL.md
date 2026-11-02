---
name: herdr-coordinator
description: 协调者工作流：本 omp 会话只做理解、规划、拆分、集成、终审，把大量实现、调试、修测试、多文件改动用 hc 委托给后台 omp worker（模型取 omp config 的 worker/reviewer 角色），每个写代码的 worker 用独立 git worktree 分支，协调者亲自验 diff、跑测试、核实际模型。用户说"用协调者/委托工作流""交给 worker 做""开 worker 并行改""起后台 worker 改代码"，或任务明显是多文件实现、需要并行或独立审查时使用；单文件小改动直接做，不用本 skill。
---

# herdr-coordinator：协调者 + hc 后台 worker 工作流

本会话是协调者。你负责项目理解、规划、任务拆分、集成和终审。实现、调试、修测试、多文件改动交给后台 omp worker。

hc 的具体命令（启动、就绪判断、发送、等待、读回、核实模型、清理）全部以 `herdr-desktop` skill 为准，先读它。本 skill 只写流程和规则，不重复那些命令。

## 方案选择原则

每次选能同时改善用户体验（UX）、开发者体验（DX）和代理体验（AX）的方案，且不破坏现有功能。三者冲突时，先保证不破坏现有功能，再说明取舍。

## worker 模型

模型不写死在命令里，取 `~/.omp/agent/config.yml` 的 `modelRoles` 角色：

| 角色 | 命令 | 用途 |
|---|---|---|
| `worker` | `omp --model worker` | 实现、调试、修测试 |
| `reviewer` | `omp --model reviewer` | 独立审查、第二意见 |

- 只用 omp。不安装、不启动 Claude Code CLI 或 Codex CLI。
- 角色指向哪个 provider/model、档位是什么，由用户在 config 里定；启动前按 `herdr-desktop`
  第 0 步读出实际值并冒烟确认。角色缺失或模型不可用时停下告诉用户，不要换模型、换 provider 或降档位。

## 1. 先判断要不要委托

- 委托：大量实现、调试、修测试、多文件改动、需要独立审查。
- 自己做：单文件小改、只读问答、一两条命令能完成的事。为小事开 worker，启动和上下文交接的成本比活本身大。

## 2. 拆分并说明分工

先用一两段话告诉用户分工：几个 worker、各做什么、哪些并行、谁审查。然后在同一轮里把独立任务全部启动，不要启动一个等一个。

并发数按三项定，最多 10 个，不必用满：

```sh
uptime; nproc     # load average 接近或超过 nproc 时少开
```

- 任务量：只有真正独立的切片才各开一个 worker。
- 配额：上一轮 worker 的 jsonl 里出现 429 或 `errorMessage`，就减少并发。

## 3. 隔离写入

- 并行改代码时，每个 worker 一个 worktree、一个分支。共享 checkout 中不允许两个 worker 写同一路径。
- worktree 从已提交的 HEAD 创建，协调者未提交的改动不会带过去。需要的话先提交，或在任务里写明。
- 本机没有全局 git 身份。委托前确认仓库有本地身份，worktree 会继承它：

```sh
git -C <repo> config user.email          # 为空则 worker 无法提交，先告诉用户
git -C <repo> worktree add -b hc/<task> ../<repo名>-wt/<task> HEAD
```

worker 的 `--cwd` 就是这个 worktree 路径。

## 4. 任务合同

worker 看不到本会话，合同必须自足。每个任务都写全下面六项，并把第一条任务放进 `hc send`（就绪后发送）：

```text
目标：<要解决什么，为什么>
工作目录：<worktree 绝对路径>，分支 hc/<task>；只改 <路径范围>
上下文：<相关文件、接口约定、已知坑、运行/测试命令>
交付物：<在分支上提交的改动 + 简短说明>
完成标准：<可验证的条件，例如某测试通过、某命令输出>
回报：完成或卡住时执行 hc send <协调者地址> '<NONCE> <结果摘要 + 提交 sha>'；长内容写文件，发路径
规则：
- 不要为没人要求的罕见情况或未来情况做设计。
- 不要改合同范围外的路径。
```

- `<协调者地址>` 写字面值（`echo $HC_TERMINAL_ID` 的结果）。worker 自己的 `$HC_TERMINAL_ID` 指向它自己。
- 每个 worker 用不同的 NONCE，后面靠它核对回报来源并找到会话 jsonl。
- 前端任务额外写：优化布局、视觉细节和实际交互，并在浏览器里自测。
- 不限制 worker 自己起 subagent 或 task。它需要并行探查、跑多个独立切片时，让它自己决定怎么分；
  协调者只管合同范围和最终验收，多一层编排不需要额外授权。

## 5. 等待与反馈

- 用 `hc wait --children all`（或 `hc wait <name>`）等待，不要 sleep 轮询。
- 返工意见用 `hc send <原 worker>` 发回去，让它在原对话里接着改。重开 worker 会丢掉它已有的上下文。

## 6. 协调者亲自验收

worker 说"完成"只是一个说法，不是证据。逐项自己确认：

1. 看实际 diff：`git -C <repo> diff HEAD...hc/<task>`，确认只动了合同范围内的路径。
2. 集成到当前分支（`git merge --no-ff hc/<task>` 或 cherry-pick），冲突由你解决。
3. 集成后统一跑一次必要的 build/lint/test。不要让每个 worker 各跑一遍再拼结论。
4. 页面改动要打开浏览器实测：真实操作一遍改动路径，截图看结果。
5. 按 `herdr-desktop` 第 5 步，用 NONCE 找到每个 worker 的会话 jsonl，读 assistant 消息的 provider/model。与角色指向的模型不一致时告诉用户。

## 7. 独立审查

代码改动集成后，另开一个没参与实现的 reviewer worker（`omp --model reviewer`）做审查。审查合同里写明：

```text
审查范围：<repo> 上 <base>..<head> 的改动（给出命令 git diff <base>..<head>）。
每个 bug 按发生频率和严重程度各打 1–10 分。
两项乘积 >= 5：可在 worktree 分支 hc/review 上修复并提交，回报 sha。
两项乘积 < 5：只记录问题（位置、现象、两项分数），不改代码。
不要为没人要求的罕见情况或未来情况做设计。
```

审查给出的修复同样走第 6 步验收。

## 8. 收尾与报告

清理：

```sh
hc kill <worker> && hc rm <address>                      # 不再需要的 worker
git -C <repo> worktree remove ../<repo名>-wt/<task>      # 删 worktree，保留分支和提交
```

- 保留继续工作需要的分支、提交，以及 `~/.omp/agent/sessions/` 下的会话记录。
- 只清理自己启动的 terminal 和 worktree。

最后向用户报告三部分：

- 结果：做了什么，合进了哪个分支、哪些提交。
- 实测验证过的内容：跑过的命令和结果、浏览器实测、各 worker 的实际模型。没跑过的不写成已验证。
- 未解决的问题：包括审查中乘积 < 5、只记录未修的条目。
