---
name: git-destructive-op-guard
description: |
  `git checkout -- .` / `git reset --hard` / `git restore --worktree .` / `git stash` / `git clean -fdx`
  在多人共用的 checkout 里会静默抹掉其他会话的未暂存改动，且未暂存内容从没进过对象库，
  `git fsck --lost-found` 挖不出来，不可恢复。此技能给出 omp harness 侧的拦截配置、验证命令与恢复边界。
  Use when: (1) 准备执行任何整树范围的 git 还原/清理命令，
  (2) 看到 `git checkout is blocked:` / `git reset is blocked:` / `git stash is blocked by workspace policy`
  / `Blocked by bash pattern: git clean*` / `Tool "bash" is blocked by tool policy`，
  (3) 怀疑自己或别的会话丢了未提交改动（`git status` 突然干净、文件回到 HEAD 版本），
  (4) 需要在共享 checkout 里丢弃改动或切换历史，要找放行路径。
author: yanzhou
version: 1.0.0
date: 2026-11-13
---

# 共享 checkout 里的破坏性 git 命令

## Facts

| # | 事实 | 证据 | 复核命令 | 生效条件 | 记录日期 |
|---|------|------|----------|----------|----------|
| F1 | `git checkout -- .` 把工作区全部未暂存改动还原为索引内容，`git status --porcelain` 随即变空 | 夹具仓库两文件均 `M`，执行后 `git status` 无输出，内容回到 `v1` | 在一次性仓库改两个已跟踪文件后执行 `git checkout -- .`，再看 `git status --porcelain` | git 2.34+ | 2026-11-13 |
| F2 | 已暂存改动能活过 `git checkout -- .`；工作区从索引重建，内容还在对象库 | 夹具中 `git add` 后执行，`mine.txt` 仍为 `staged-v2`，`git rev-parse :mine.txt` 有 blob | 同上，改动先 `git add` 再执行 | 同上 | 2026-11-13 |
| F3 | 被 `git checkout -- .` 抹掉的未暂存内容不可恢复：`git fsck --lost-found` 找不到对应 blob | 夹具执行后 `git fsck --lost-found \| grep -c blob` 输出 `0` | 同上，执行后跑 `git fsck --lost-found` | 未暂存 = 从未 `git add` | 2026-11-13 |
| F4 | `bash.gitGuard: true` 时，`git checkout -- .`、`git checkout HEAD -- .`、`git restore --worktree .`、`git reset --hard`、`git stash`、`git switch <branch>` 全部被拒，exit=1，工作区不变 | 六条命令逐条执行，均 exit=1 且 `cat` 目标文件仍为新值 | `git checkout -- .` 于脏工作区（须在共用 checkout 内） | omp 18.20.0, `bash.gitGuard: true` | 2026-11-13 |
| F5 | `bash.gitGuard` 不拦 `git clean -fdx`；该命令 exit=0 并删掉未跟踪文件 | 夹具中被删文件 `ls` 报 `No such file or directory` | 一次性仓库放一个未跟踪文件后 `git clean -fdx` | omp 18.20.0 | 2026-11-13 |
| F6 | `bash.patterns` 加 `{"match":"git clean*","approval":"deny"}` 后，bash 工具整条命令被拒：`Tool "bash" is blocked by tool policy.` + `Blocked by bash pattern: git clean*`；`git clean -n*` 前置 allow 项仍放行 dry-run | 单条 `git clean -fdx` 被拒，单条 `git clean -n --dry-run` exit=0 | `git clean -fdx` 于一次性仓库 | 同上，规则顺序 allow 在 deny 前 | 2026-11-13 |
| F7 | 在 `git worktree add <path> -b <br>` 建的自有 worktree 内，同类命令放行且自动保存：`git checkout: saved your uncommitted changes as <sha> on refs/omp/discarded first` | 自有 worktree 内 `git checkout -- .` exit=0 并打印该行 | 建 worktree 后在其中改文件再执行 | 同上 | 2026-11-13 |
| F8 | eval 内核里 `sh("git checkout -- .")` 同样被拦（走 bash 工具），但 `subprocess.run(["git","checkout","--","."])` 直接执行成功并破坏工作区 | `sh()` 抛 ShellError exit 1；`subprocess.run` 返回 0，文件被改回旧值 | 在 eval 单元格里分别跑两种调用 | 同上 | 2026-11-13 |

## Model

**机制链**：未暂存的编辑只存在于工作区文件 → 整树还原命令用索引中的 blob 覆写工作区 → 这些编辑从未
被写进对象库，所以没有 blob 可供 `fsck` 找回 → 内容永久丢失，且 git 不报错、不备份。
已暂存的编辑有 blob，所以能活下来；这是"先 `git add` 再动刀"的唯一价值所在。

**分类树**（同症状"工作区突然变干净"，不同根因）：

- 整树丢弃：`git checkout -- .`、`git checkout <rev> -- .`、`git restore --worktree .`、`git reset --hard`
- 历史移动：`git switch <branch>`、`git checkout <branch>`
- 未跟踪删除：`git clean -fd` / `-fdx`（连未跟踪文件一起，`fsck` 同样找不到）
- 共享工作抽取：`git stash`（把别人的未提交改动一起抽走）
- 非 git 的同类事故：脚本内 `rm -rf`、`cp` 覆写、installer 覆盖配置

**判别标准**：

| 近似情形 | 区分信号 |
|---|---|
| 自己误删 vs 别的会话动了同一 checkout | `git reflog` 无相关记录而工作区已干净 → 不是自己 commit 造成的；`git log --oneline -3` 未变 |
| 已暂存（可救）vs 未暂存（不可救） | `git diff --cached --stat` 有内容 = 对象库里有 blob，可救；`git diff --stat` 才有的内容 = 不可救 |
| 已跟踪文件被还原 vs 未跟踪文件被删 | `git status -uall` 中消失的路径原本是否在 `git ls-files` 里 |
| 守卫拦截 vs 命令自身报错 | 拦截文案含 `blocked by workspace policy` / `Blocked by bash pattern` / `Tool "bash" is blocked by tool policy`；git 自身报错不含这些 |

**边界**：

- 这层防护是 **harness 的工具层策略**，不是 git hook、不是内核、不是文件系统保护。任何绕开 bash 工具的
  进程调用（`subprocess.run`、`os.system`、脚本内部调 git）都不被拦——F8 实测。
- 自有 worktree（`git worktree add`）内放行，因为那份工作区只有你一个使用者（F7）。
- 合并/变基冲突解决期间，`git checkout -- <path>` 与 `git restore <path>` 放行。
- `git stash` 仍可用只读子命令：`git stash list`、`git stash show`、`git stash create`。

## Checks

| # | 纠正 | 形态 | 接线位置 | 检查命令 | 通过判据 | 负控 | 记录日期 |
|---|---|---|---|---|---|---|---|
| X1 | 在共享 checkout 里跑整树丢弃命令，抹掉其他会话未暂存的改动 | eliminate | `omp/config.yml` 的 `bash.gitGuard: true`（`omp config set bash.gitGuard true`），由 bash 工具执行前判定 | `bash scripts/verify-agent-guards.sh` | exit=0，输出 `PASS  bash.gitGuard = true` | 用假 `omp` 桩返回 `false` 时脚本 exit=1，输出 `FAIL  bash.gitGuard = 'false'` | 2026-11-13 |
| X2 | `git clean -fdx` 静默删掉未跟踪文件（`bash.gitGuard` 的缺口） | lint | `omp/config.yml` 的 `bash.patterns`：`[{"match":"git clean -n*","approval":"allow"},{"match":"git clean*","approval":"deny"}]` | `bash scripts/verify-agent-guards.sh` | exit=0，输出 `PASS  bash.patterns 拦截 git clean*` | 用假 `omp` 桩只回 allow 项时脚本 exit=1，输出 `FAIL  bash.patterns 缺 git clean* 的 deny 规则` | 2026-11-13 |

**无法自动化的纠正**：

| # | 纠正 | 为何 L1–L7 都不可行 | 退而求其次 | 复审触发 |
|---|---|---|---|---|
| X3 | 别把破坏性 git 命令交给 eval 内核的 `subprocess.run` / `os.system` | eval 内核可 fork 任意进程，harness 不解析其参数；没有可挂载的拦截点（git 无 pre-checkout hook） | 写进 §Procedure 的决策表：一次性 destruct 只走 bash 工具或自有 worktree | omp 给 eval/子进程加命令策略时重评 |
| X4 | 破坏性操作前先确认自己没有该丢的未暂存改动 | 判据是人对自己意图的判断，机器无法知道"这次改动该不该丢" | 用 F2/F3 的判别标准（`git diff --cached` vs `git diff`）做人工前检 | — |

## Procedure

**前置条件**：在共享 checkout 里，且 `bash scripts/verify-agent-guards.sh` exit=0。

**决策表**：

| 入口观测 | 分支 |
|---|---|
| 要丢掉自己刚写的未提交改动 | B1 别还原，改为「正向编辑」回去，或用 `git worktree add` 到自有 worktree 再操作 |
| 要切分支 / 看别的 revision | B2 只读查看：`git show <rev>:<path>`、`git diff <rev>`、`git log`；要真检出就 `git worktree add` |
| 要暂存当前工作去做别的事 | B3 `git stash` 被拦；改为 `git add -A` 后提交到临时分支（对象库里就有 blob，可救） |
| 要清理未跟踪文件 | B4 先 `git clean -n`（dry run，放行）确认清单；确认后用 `git status -uall` 人工删除具体路径，不要用 `-f` |
| 已经在冲突解决中 | B5 `git checkout -- <path>` / `git restore <path>` 可用；不要用整树形式 |
| 发现工作区已被清空 | B6 走 S1 |

**B1 自有 worktree**

1. `git worktree add /tmp/wt-<name> -b <branch>`
   - 期望：`Preparing worktree (new branch '<branch>')`
   - 不匹配：路径已存在则换名，或 `git worktree list` 先看有没有可复用的
2. 在 worktree 内执行破坏性操作
   - 期望：放行；若真的丢了改动，输出 `saved your uncommitted changes as <sha> on refs/omp/discarded first`
   - 不匹配：没出现该行而改动已丢 → 转 S2

**回滚**：worktree 内被保存的改动用 `git stash apply --index <sha>` 取回（F7 的文案给出该命令）。

**停止条件**：

- S1：`git status --porcelain` 为空但确定刚写过内容 → 立即停手，不要再执行任何 git 写操作；先 `git fsck --lost-found`（F3 实测通常为空）、查 `~/.cache`、编辑器 swap/undo、其他会话是否还持有该内容。不要尝试"再改一遍试试"。
- S2：worktree 内也未提示 saved → 该改动从未进对象库，按 S1 处理。

## Calibration

**逐条置信度**：

| 事实/结论 | 置信度 | 依据 |
|---|---|---|
| F1 | verified | 夹具仓库执行前后 `git status` 对比 |
| F2 | verified | `git add` 后执行，`git rev-parse :mine.txt` 有 blob |
| F3 | verified | `git fsck --lost-found \| grep -c blob` = 0 |
| F4 | verified | 六条命令逐条 exit=1 |
| F5 | verified | `git clean -fdx` exit=0 且文件消失 |
| F6 | verified | deny 与 allow 两条路径分别实跑 |
| F7 | verified | 自有 worktree 内 exit=0 并打印 saved 行 |
| F8 | verified | `sh()` 抛 ShellError，`subprocess.run` 返回 0 并破坏文件 |
| X1/X2 负控 | verified | 假 `omp` 桩实跑，exit=1 |
| "macOS / 其他 omp 版本行为相同" | assumed | 只在 Linux + omp 18.20.0 验证 |

**证伪条件**（出现即本技能失效或需重写）：

- omp 升级后 `bash.gitGuard` 的拦截范围变化（例如开始拦 `git clean`），此时 X2 可降级删除。
- `bash.patterns` 的 `match` 语义从"整条命令或任一段"改为别的口径，X2 的负控会失效。
- git 引入 pre-checkout hook 或 `safe.directory` 之外的工作区保护机制，边界段需重写。

**未知清单**：

- 未验证 `bash.gitGuard` 对 `git restore --source=<rev> .`、`git checkout <tree-ish> -- <dir>/`（目录形式非 `.`）是否同样拦截。验证方法：一次性仓库逐条跑。
- 未验证 eval 内核以外的其他 spawn 路径（插件、MCP server、后台 job）是否也被拦。
- 未验证 Windows/macOS 上 harness 是否同样生效。

**复审日期**：2027-05-13（到期重跑 F4–F8 与 X1/X2 负控）

**使用台账**：

| 日期 | 场景 | 结果 |
|---|---|---|
| 2026-11-13 | 首次抽取：自己在共享 checkout 跑 `git checkout -- .`，抹掉他人 84 行未暂存改动且不可恢复 | 已落地 X1/X2，正负控全过 |
