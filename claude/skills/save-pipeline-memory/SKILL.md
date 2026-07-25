---
name: save-pipeline-memory
description: |
  Capture the current session's workflow pipeline memory into a timestamped
  markdown file inside a user-specified folder. The core output is the final
  working pipeline written as clean, reproducible steps; the detours, failed
  attempts and pitfalls hit along the way are recorded separately as lessons.
  Timestamped snapshots stay in pipeline_memory/ (not auto-loaded); when a
  pipeline is mature it can be promoted into pipeline_memory/PIPELINE.md and
  imported by the project CLAUDE.md via @pipeline_memory/PIPELINE.md so future
  sessions load it automatically. Use when the user wants to checkpoint or
  persist a working pipeline so a future session can reproduce it, when
  finishing a stage of a multi-step task, or when the user says things like
  "保存工作流记忆", "save pipeline memory", "记录一下当前进展",
  "让 CLAUDE.md 能看到 pipeline", "/save-pipeline-memory". Takes an optional
  folder path as argument.
---

# Save Pipeline Memory

在 session 运行过程中，把当前工作流的"记忆"整理成一个带时间戳的 Markdown 文件，
保存到用户指定的文件夹，供未来的 session 续接或回顾。

这是**手动触发**的 skill：由用户调用（`/save-pipeline-memory [文件夹路径]`）或在
完成阶段性工作时使用。它依赖 Claude 对当前会话的理解来智能归纳，不做机械 dump。

## 核心理念：主角与配角

- **主角 = 最终能跑通的 pipeline**：把成功路径提炼成干净、有序、可直接复现的步骤，
  剔除所有试错。读者照着这一节就能重新跑通，不必趟坑。
- **配角 = 弯路与经验**：中间试过但没走通的方案、踩过的坑，单独记录，作为
  "为什么最终方案长这样"的注脚，帮未来避免重走弯路。

两者严格分开——绝不把失败的命令混进最终 pipeline。

保存的记忆文件包含这几节：会话概览、✅ 最终可跑通的 Pipeline（主角）、
💡 弯路与经验（配角）、关键决策、产出与指标、下一步。

## 两层存储：探索快照 vs 定稿 pipeline

Claude Code 每个 session **只自动加载 `CLAUDE.md`**（及其用 `@路径` 导入的文件），
不会自动扫描 `pipeline_memory/`。据此分两层：

- **探索快照（不自动加载）**：带时间戳的 `pipeline_memory/YYYY-MM-DD_HHMM_*.md`，
  含弯路经验，是过程档案。故意不自动加载，避免每个 session 都被试错档案塞满上下文。
- **定稿 pipeline（自动加载）**：当某条 pipeline 探索成熟、确认跑通后，把那条**干净的
  最终 pipeline** 提炼进 `pipeline_memory/PIPELINE.md`（单一真相源、无弯路），并在项目
  `CLAUDE.md` 里加一行 `@pipeline_memory/PIPELINE.md` 导入，使每个新 session 自动带上它。

普通保存只产出探索快照（第 1-4 步）。当 pipeline 确认成熟时，额外执行第 5 步提炼定稿。

## 工作流程

### 第 1 步：确定保存文件夹

按以下优先级确定目标文件夹：

1. 用户调用时传入的路径参数（`args`），如 `/save-pipeline-memory ~/pipeline-memory`。
2. 若无参数，检查当前工作目录下是否已有 `pipeline_memory/` 目录，有则用它。
3. 都没有，则默认用 `<cwd>/pipeline_memory/`，并**在创建前明确告知用户将要创建的路径**。

确定后用 `mkdir -p <目标文件夹>` 确保目录存在。

### 第 2 步：区分主角与配角，收集记忆

回顾**当前整个 session** 的上下文，做一次关键的分拣：

1. **先还原最终跑通的路径**：哪些步骤、命令、配置是真正让事情成功的？把它们排成
   一条干净、有序、可复现的序列，剔除中途的失败尝试。这是主角。
2. **再收集弯路**：过程中试过但没走通的方案、踩过的坑、报过的错——归入配角，
   每条都要落到"教训"或"因此选择了 X"，不要只记流水账。

收集时：
- 优先从已发生的工具调用、命令输出、文件改动中提取事实，不要凭空编造。
- 若本 session 尚未跑通，如实把状态标为"部分跑通/未跑通"，最终 pipeline 一节
  只写已确认有效的部分，剩余写进"下一步"。
- 对运行时状态、验证结果这类断言，只写你实际验证过的；没验证的标注清楚。

如需查证当前环境状态，可运行只读命令（如 `git status`、`git log --oneline -5`、
`git rev-parse --abbrev-ref HEAD`）来填充分支/commit 等元信息。

### 第 3 步：按模板写入文件

读取 `references/memory-template.md` 获取完整的文件结构和填写要点，然后：

- 文件名格式：`YYYY-MM-DD_HHMM_<kebab-case-任务描述>.md`
- 用 `date +%Y-%m-%d_%H%M` 获取时间戳前缀，避免手写出错。
- 必填"会话概览"和"✅ 最终可跑通的 Pipeline"两节；有弯路则填"💡 弯路与经验"。
- 最终 pipeline 一节里绝不放失败的命令；失败尝试一律进"弯路与经验"。
- 若任务未跑通，"下一步 / 未解决"一节必须写清楚，这是续接的关键。

### 第 4 步：确认

写完后向用户报告：保存到了哪个文件、最终 pipeline 有几步、记了几条弯路经验、
文件行数。不要复述全文。

### 第 5 步（可选）：提炼定稿 pipeline 到 CLAUDE.md

仅当 pipeline **确认成熟、稳定跑通**，且用户希望它对未来 session 自动可见时执行。
判断标准：状态为"已跑通"，且这条 pipeline 会被反复使用/续接。

1. 把这次（及历史快照里）**干净的最终 pipeline** 提炼、合并进
   `<保存文件夹>/PIPELINE.md`。这是单一真相源：只保留可复现的成功步骤，
   不含弯路，不带时间戳文件名那套命名。若已存在则**就地更新对应小节**，
   而非追加重复内容。
2. 确保项目 `CLAUDE.md` 里有导入行。检查是否已存在，没有才追加：
   ```
   @pipeline_memory/PIPELINE.md
   ```
   （路径按 `PIPELINE.md` 相对于 `CLAUDE.md` 的实际位置调整。若保存文件夹在项目外，
   `@` 导入需用相对/绝对路径，且要提醒用户该文件在仓库外、他人 clone 后看不到。）
3. 向用户说明：探索快照仍留在 `pipeline_memory/` 供回溯，定稿已进 `PIPELINE.md`
   并通过 `CLAUDE.md` 自动加载。

修改 `CLAUDE.md` 前先读它，确认导入行不重复；这是对项目共享文件的改动，动作要克制。

## 安全与质量约束

- **不泄密**：遇到密钥、token、`.env` 内容，用键名引用（`API_KEY=<redacted>`），
  绝不把明文值写进记忆文件。
- **诚实记录**：最终 pipeline 只写确认跑通的；没跑通就如实标状态并把缺口写进下一步。
- **弯路要有结论**：每条弯路都要落到教训或"因此选择了 X"，否则不值得记。
- **精炼**：只记非显而易见、对未来有用的信息。
- **不覆盖**：每次生成新的时间戳文件，绝不覆盖已有记忆文件。

## 与其他 skill 的关系

本 skill 关注"把跑通的工作流现场固化下来"。若目标是为项目搭建**长期调试知识库体系**
（规则文件 + 目录规范 + 团队流程），那是 `debug-experience-system` 的职责。
两者可配合：本 skill "弯路与经验"里的坑可沉淀进调试知识库。
