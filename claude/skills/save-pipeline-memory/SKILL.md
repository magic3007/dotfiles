---
name: save-pipeline-memory
description: |
  Capture a multi-step workflow into a timestamped pipeline memory after trial-and-error
  sessions. The core output is: (1) the final working commands saved as executable scripts
  (not bare shell commands), and (2) a structured markdown document separating the clean
  reproducible pipeline from the detours and pitfalls. Timestamped snapshots live in
  pipeline_memory/; mature pipelines can be promoted to PIPELINE.md and auto-loaded.
  Fully environment-agnostic — works for any project, any toolset, any domain. Use when
  the user finishes a multi-step task, says "保存工作流记忆", "save pipeline memory",
  "记录一下当前进展", or "/save-pipeline-memory". Takes an optional folder path.
---

# Save Pipeline Memory

在经历多轮试错之后，把最终跑通的工作流固化下来。核心产出两样东西：
1. **可执行的脚本** — 最终能跑通的命令，封装为接受参数的脚本，别人拿到就能跑
2. **Pipeline Memory 文档** — 干净的可复现步骤 + 弯路经验的分离记录

本 skill 是**通用方案**，不绑定任何特定项目、工具或环境。

## 核心理念

```
试错过程                    最终产出
─────────                  ────────
手拼命令 → 失败             ✅ 脚本（可重复运行）
改参数   → 失败              📝 Pipeline Memory（可复现步骤）
再试     → 成功             💡 弯路经验（避免重蹈覆辙）
```

- **脚本化是终点**：最终 pipeline 里的每一步必须是一个脚本调用，不是手拼的裸命令。
  脚本接受参数、不硬编码路径、从配置文件自动读取可推导值。
- **主角与配角分离**：成功路径放进 "✅ Pipeline"，试错过程放进 "💡 弯路与经验"。

## 两层存储

| 层级 | 文件 | 何时加载 | 内容 |
|------|------|---------|------|
| 探索快照 | `pipeline_memory/YYYY-MM-DD_HHMM_<描述>.md` | 不自动加载 | 完整记录（含弯路） |
| 定稿 pipeline | `pipeline_memory/PIPELINE.md` | 通过 `CLAUDE.md` 自动加载 | 只含干净的最终步骤 |

## 工作流程

### 第 1 步：确定保存位置

1. 用户传入的路径参数（如 `/save-pipeline-memory ~/my-project`）
2. 若未传参，检查当前目录下是否已有 `pipeline_memory/`
3. 都没有，用 `<cwd>/pipeline_memory/`，先告知用户

### 第 2 步：提取脚本（核心步骤）

回顾 session 中最终跑通的命令，将其**改写为可执行脚本**，保存到合适的位置（项目 `scripts/` 或 `pipeline_memory/scripts/`）：

- 脚本接受 CLI 参数，不硬编码路径或值
- 从配置文件（JSON/YAML/meta 文件）自动读取可推导的参数
- 复制已验证成功的配置作为模板，只 patch 必要字段
- 确保另一人拿到脚本 + 数据就能复现，无需从 memory 里复制粘贴

**不要在 memory 里记录手拼的裸命令**（如 `tool submit --flag1 --flag2 ...`），除非该步骤确实无法脚本化。

### 第 3 步：写入 Pipeline Memory

按 `references/memory-template.md` 模板写入时间戳文件：

- `YYYY-MM-DD_HHMM_<kebab-case-描述>.md`
- 必填：会话概览、✅ Pipeline（脚本调用形式）、💡 弯路与经验
- Pipeline 一节里不放失败命令，不放裸 shell 命令
- 未跑通的步骤写进「下一步」

### 第 4 步：同步飞书文档（如项目配置了飞书文档）

检查 `CLAUDE.md` 或用户指定是否有关联的飞书文档。如果有，将以下信息同步过去：

**必须更新的内容**：

1. **全链路状态表** — 每个步骤的 Job ID（带可点击链接）、状态、输入/输出绝对路径
2. **数据组成表** — 每个数据源的绝对路径、样本数、Token 占比
3. **训练/评测结果表** — 关键指标（avg_pass1、train_iters 等）
4. **向上管理摘要** — 当前阶段、阻塞项、下一步，方便管理者一眼看懂进展

**格式要求**：

- **表格优先**：多步骤状态、参数配置、数据源 → Markdown 表格
- **链接强制**：每个 Job/Task/Model ID 必须带可点击链接，不写裸 ID
- **绝对路径**：每个文件/脚本/数据一律写完整绝对路径
- **描述性文字**：每个章节加一段"目的/背景"说明，让人不需要翻代码就能读懂
- **图表尽可能多**：状态、占比、对比都用表格呈现，不写纯文字列表

### 第 5 步：确认

报告保存位置、Pipeline 步数、弯路条数、产出的脚本文件、飞书文档更新情况。

### 第 6 步（可选）：提炼 PIPELINE.md

当 pipeline 成熟稳定后：
1. 将干净步骤提炼进 `PIPELINE.md`（单一真相源，无弯路）
2. 在项目入口文件（如 `CLAUDE.md`）中添加 `@pipeline_memory/PIPELINE.md` 导入
3. 探索快照保留供回溯

## 质量约束

- **脚本化优先**：最终 pipeline 每一步是脚本调用，不是裸命令
- **环境无关**：不假定特定工具名（如 mmctl/vela），用通用描述替代
- **不泄密**：密钥/token 用键名引用（`API_KEY=<redacted>`）
- **弯路有结论**：每条弯路落到教训或"因此选择了 X"
- **诚实标注**：未跑通的如实标状态
- **文档可复现**：飞书文档中的每一步都要有链接+绝对路径，另一个人照着就能操作
