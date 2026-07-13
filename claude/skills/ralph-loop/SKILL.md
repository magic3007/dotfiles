---
name: ralph-loop
description: >
  Ralph Wiggum 迭代开发循环。三阶段工作流（需求→规划→构建），每阶段有 code review + 测试 gate。
  触发词：ralph loop、迭代开发、interview me、plan system、build system。
---

# Ralph Loop v2 (Claude Code Edition)

基于 Geoffrey Huntley 的 Ralph Wiggum 技术的自主迭代开发。

**核心：** 每个阶段有强制 **code review + 测试** gate，不通过不进下一阶段。

---

## 触发短语

| 短语 | 动作 |
|------|------|
| "Ralph loop over X" | **问走哪个阶段** |
| "Interview me about X" | Phase 1: 需求收集 |
| "Plan system X" | Phase 2: 规划循环 |
| "Build system X" | Phase 3: 构建循环 |

---

## 核心原则

1. **Context 是稀缺的** — 每次迭代做合理的一块工作，不贪多也不过少
2. **你只是任务中的一环** — loop.sh 驱动迭代，每次 CLI 调用是独立的 context，做完合理粒度就退出
3. **计划是一次性的** — 跑偏了重新规划，不硬撑
4. **背压 > 方向** — 测试 + review 自动拒绝错误输出
5. **每阶段有 gate** — code review + 测试通过才能推进

---

## 三阶段工作流

```
Phase 1: REQUIREMENTS ──── 人机对话 → specs/*.md
    Gate: 用户确认所有 spec

Phase 2: PLANNING ──────── 差距分析 → IMPLEMENTATION_PLAN.md
    Gate: Plan review + 验证（命令存在、路径有效）

Phase 3: BUILDING ──────── 迭代实现 → test → Codex review → commit
    Gate: 测试通过 + Codex cross-review（完成时）
```

### 阶段检测

| 当前状态 | 阶段 | 动作 |
|---------|------|------|
| 没有 `specs/` 或为空 | Phase 1 | 跑需求访谈 |
| 有 `specs/*.md`，没有 `IMPLEMENTATION_PLAN.md` | Phase 2 | 跑规划循环 |
| 有 spec + plan | Phase 3 | 跑构建循环 |
| Plan 显示全部完成 | Done | 汇报 |

---

## Phase 1: 需求收集（人机对话）

**目标：** JTBD → Topics → `specs/*.md`

1. 识别 Jobs to Be Done（结果，不是功能）
2. 拆分成 Topics — 每个通过「一句话不带 AND」测试
3. 写 `specs/<topic>.md`，包含验收标准 + 边界情况
4. **Gate：** 用户明确确认所有 spec

---

## Phase 1→2 过渡：初始化 .ralph/

Phase 1 specs 确认后，**立即初始化 `.ralph/` 目录**：

1. 收集配置信息（用 AskUserQuestion）：
   - CLI 工具：`claude` / `codex` / `opencode` / `goose`（默认 `claude`）
   - 背压命令：如 `npm test && npm run typecheck && npm run lint`
   - 最大迭代次数：默认 `0`（无限）

2. **用 `cp` 复制模板文件**到项目的 `.ralph/`，然后在副本上编辑（不要读模板再重写！）：
   ```bash
   mkdir -p .ralph/state
   cp /path/to/skill/templates/loop.sh .ralph/loop.sh
   cp /path/to/skill/templates/PROMPT_plan.md .ralph/PROMPT_plan.md
   cp /path/to/skill/templates/PROMPT_build.md .ralph/PROMPT_build.md
   chmod +x .ralph/loop.sh
   ```
   **模板源路径：** 此 skill 基础目录下的 `templates/`

3. 在复制后的文件上替换占位符：
   - `.ralph/loop.sh` 中替换 `{{CLI}}`、`{{MODE}}`、`{{MAX_ITERS}}`、`{{BACKPRESSURE_CMD}}`
   - `.ralph/PROMPT_plan.md` 中替换 `[PROJECT_GOAL]` 和源码路径
   - `.ralph/PROMPT_build.md` 中替换源码路径

4. 如果项目根目录没有 `AGENTS.md`，从 templates 复制一份并让用户适配

---

## Phase 2: 规划循环

**目标：** 生成 `IMPLEMENTATION_PLAN.md` — 不实现任何东西。

**执行方式：Claude Code 直接在 Bash 中运行 loop.sh：**

```bash
cd /path/to/project && .ralph/loop.sh plan
```

loop.sh 会用 `PROMPT_plan.md` 反复调用 AI CLI，直到 `IMPLEMENTATION_PLAN.md` 中出现 `STATUS: PLANNING_COMPLETE`。

### 规划 Gate（必须通过才能进 Phase 3）

loop.sh plan 完成后，Claude Code **自动读取并展示** `IMPLEMENTATION_PLAN.md` 给用户 review：

- [ ] `IMPLEMENTATION_PLAN.md` 存在，任务有优先级
- [ ] 每个任务范围清晰（一句话描述）
- [ ] 验证命令确实能跑（`npm test` 等）
- [ ] 没有依赖未定义的需求
- [ ] 用户已 review 确认

Review 通过后，**Claude Code 立即启动 Phase 3**（不要让用户手动运行）。

---

## Phase 3: 构建循环

**目标：** 迭代实现任务，保持 context 新鲜。

**执行方式：Claude Code 直接在 Bash 中运行 loop.sh：**

```bash
cd /path/to/project && .ralph/loop.sh build
# 或限制迭代次数：
cd /path/to/project && .ralph/loop.sh build 50
```

loop.sh 会用 `PROMPT_build.md` 反复调用 AI CLI，每次迭代自动执行：

```
1. 读 IMPLEMENTATION_PLAN.md → 挑合理粒度的任务
2. 调研代码库（不要假设没实现！）
3. 实现任务
4. 跑背压：测试 + typecheck + lint
5. Code review：对照 spec 验收标准
6. 更新 IMPLEMENTATION_PLAN.md
7. git commit + git push（有 remote 时）
8. AI CLI 退出 → loop.sh 启动下一轮（全新 context）
```

如果背压失败，loop.sh 把错误写入 `.ralph/state/last-feedback.txt`，下一轮 AI 会自动收到并尝试修复。

如果 AI 判断自己卡住了，会创建 `RALPH-BLOCKED.md`，loop.sh 检测到后停止，等人工介入。

所有任务完成后，AI 在 `IMPLEMENTATION_PLAN.md` 中写入 `STATUS: COMPLETE`。loop.sh 检测到后会自动运行 **cross-review**（优先独立 reviewer，fallback 到 self-review）：
- Review 通过（LGTM）→ loop.sh 自动退出，构建完成
- Review 不通过 → 问题和修复建议写入 `last-feedback.txt`，`STATUS: COMPLETE` 被撤回，下一轮继续修复
- **连续 review 不通过达到软上限**（默认 15 轮，`RALPH_MAX_REVIEW` 可配）→ loop.sh 写入 checkpoint 文件并 exit 2，外层 agent 判断是否继续

### 迭代 Gate（每次迭代必须通过）

- [ ] **测试通过** — 所有验证命令成功
- [ ] **Code review** — 实现符合 spec 验收标准
- [ ] **无回归** — 之前的测试仍然通过
- [ ] **Plan 已更新** — 任务标记完成
- [ ] **Clean commit** — 描述性提交信息

### 覆盖率要求

| 指标 | 目标 |
|------|------|
| 行覆盖率 | ≥ 80% |
| 分支覆盖率 | ≥ 70% |
| 新代码覆盖率 | ≥ 90% |

---

## 自动过渡

**Phase 2 → Phase 3 自动过渡流程：**

1. `loop.sh plan` 完成（检测到 `STATUS: PLANNING_COMPLETE`）
2. Claude Code 读取 `IMPLEMENTATION_PLAN.md` 展示给用户
3. 用户确认后，Claude Code 立即运行 `loop.sh build`
4. **不要让用户手动执行任何命令**

**Phase 3 退出码处理：**

```
loop.sh build 退出:
  exit 0   → 完成（LGTM 或 PLANNING_COMPLETE）
  exit 1   → 失败（max iterations 或 blocked）
  exit 2   → review checkpoint，需要 agent 判断
  exit 130 → 用户 Ctrl+C
```

**Exit 2 处理流程（review 软上限）：**

1. 读取 `.ralph/state/review-checkpoint.md`
2. 分析剩余问题严重性（Critical/High vs Low/Medium）和重复度
3. 判断：
   - 如果是高价值修复 → 删除 checkpoint，重新运行 `loop.sh build`（round 重置为 0）
   - 如果是低价值/重复问题 → 设 `STATUS: COMPLETE`，删除 checkpoint，告知用户完成
4. **不要让用户手动处理 exit 2**

---

## 背压机制

三层，按顺序叠加：

### 1. 硬 Gate（必须）
测试、typecheck、lint、build。确定性、快速。

### 2. Code Review Gate（必须）
每次迭代后验证：
- 实现符合 spec 验收标准
- 没有 shortcuts/stubs/placeholders
- 和现有模式一致

### 3. Codex Cross-Review Gate（完成时）
所有任务完成、`STATUS: COMPLETE` 写入后：
- loop.sh 自动调用 Codex 进行全面 review
- Codex 提供具体修复建议（不只是 pass/fail）
- 通过 → 真正完成；不通过 → 反馈回 Claude 继续修复

---

## 完成检测

```bash
# Plan phase
grep -Fq "STATUS: PLANNING_COMPLETE" IMPLEMENTATION_PLAN.md

# Build phase
grep -Fq "STATUS: COMPLETE" IMPLEMENTATION_PLAN.md
```

---

## 文件结构

```
project/
├── .ralph/
│   ├── loop.sh                 # 主循环脚本（cp 自模板，Claude Code 直接运行）
│   ├── PROMPT_plan.md          # 规划阶段 prompt（cp 自模板后编辑）
│   ├── PROMPT_build.md         # 构建阶段 prompt（cp 自模板后编辑）
│   ├── ralph.log               # 运行日志
│   └── state/
│       ├── iteration.txt       # 当前迭代次数（支持断点续跑）
│       ├── last-feedback.txt   # 上次失败的反馈 / review 反馈
│       ├── review-round.txt    # 连续 review 轮次（LGTM 或 builder 写新代码后重置）
│       └── review-checkpoint.md # review 软上限暂停时的 checkpoint（exit 2 时生成）
├── IMPLEMENTATION_PLAN.md      # 带优先级的任务列表（生成的）
├── AGENTS.md                   # build/test/lint 命令
├── RALPH-BLOCKED.md            # (可选) AI 卡住时自动创建，需人工介入
└── specs/                      # 需求 spec
    ├── topic-a.md
    └── topic-b.md
```

---

## Prompt Guardrails Pattern

用递增编号的 guardrails（Geoffrey 的模式）：

```markdown
99999. Important: 在文档中记录 why。
999999. Important: 单一数据源，不搞迁移。
9999999. 成功 build 后打 git tag。
99999999. 保持 IMPLEMENTATION_PLAN.md 更新。
999999999. 完整实现 — 不留 placeholder 或 stub。
```

### 关键用语
- "study"（不是 "read"）
- "don't assume not implemented"
- "Ultrathink"（深度推理触发）
- "capture the why"

---

## Quick Start

```bash
mkdir -p myproject/specs && cd myproject && git init
```

```
Phase 1: Interview → 写 specs/ → 用户确认
         ↓
过渡:    cp 模板到 .ralph/（配置 CLI、背压命令）
         ↓
Phase 2: Claude Code 运行 .ralph/loop.sh plan → 展示 plan 给用户 review
         ↓
Phase 3: 用户确认后 Claude Code 自动运行 .ralph/loop.sh build → Codex 守门 → 完成
```

### 常用命令

```bash
.ralph/loop.sh plan          # 只跑规划
.ralph/loop.sh build         # 只跑构建
.ralph/loop.sh both          # 先规划再构建
.ralph/loop.sh build 50      # 最多 50 次迭代
tail -f .ralph/ralph.log     # 实时查看日志
cat RALPH-BLOCKED.md         # 查看卡住原因（如果有）
```

---

## Troubleshooting

| 问题 | 解法 |
|------|------|
| 同一任务被重复实现 | 重新跑规划循环 |
| 原地打转 | 加更具体的测试作为背压 |
| Context 膨胀 | 确保迭代粒度合理 |
| 测试抓不到问题 | 加集成测试，不要只写单元测试 |
| Cross-review 反复不通过 | 15 轮后 exit 2 自动暂停，外层 agent 判断是否继续 |
| Exit 2 checkpoint | 读 `.ralph/state/review-checkpoint.md`，分析问题价值，决定继续或完成 |

---

## Credits

Based on work by:
- **Geoffrey Huntley** — 原始 Ralph Wiggum 技术
- **Clayton Farr** — Ralph Playbook
- **ClawHub Community** — 三阶段工作流、模板、guardrails
