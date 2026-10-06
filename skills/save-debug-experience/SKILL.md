---
name: save-debug-experience
description: |
  Record a debugging session's findings into a timestamped markdown file under
  debug_experience/. Captures problem, root cause, solution, and key learnings
  in a structured, reusable format. Use when: you've just resolved a non-obvious
  bug, found an undocumented edge case, encountered an issue that took multiple
  attempts to fix, or when you say things like "保存调试经验", "save debug experience",
  "记录这次调试", "/save-debug-experience". Takes an optional folder path as argument.
---

# Save Debug Experience

调试结束后，把本次 session 的调试过程整理成带时间戳的 Markdown 文件，保存到
`debug_experience/` 目录，供未来参考和团队共享。

这是**手动触发**的 skill：在解决完一个值得记录的问题后调用。
依赖 Claude 对当前会话的理解来智能归纳，不做机械 dump。

## 什么值得记录

只记录**非显而易见、对未来有价值**的内容：
- 需要多次尝试才能定位的 bug
- 文档未覆盖的特殊情况或边界条件
- 容易再次踩的坑
- 反直觉的根因（"居然是这个原因"）

## 工作流程

### 第 1 步：确定保存文件夹

按以下优先级确定目标文件夹：

1. 用户调用时传入的路径参数（`args`），如 `/save-debug-experience ~/myproject/debug_experience`
2. 若无参数，检查当前工作目录下是否已有 `debug_experience/` 目录，有则用它
3. 都没有，则默认用 `<cwd>/debug_experience/`，**创建前明确告知用户**

确定后用 `mkdir -p <目标文件夹>` 确保目录存在。

### 第 2 步：收集调试经历

回顾**当前整个 session**，重点提取：

1. **问题**：什么东西出错了？症状是什么？
2. **根因**：为什么会发生？深入到真正的原因，不只是表面现象
3. **解决方案**：最终走通的步骤，干净有序
4. **弯路**：试过但没走通的方案，以及为什么没走通（要有结论）
5. **关键学习**：这次调试中最重要的非显而易见的教训

收集时：
- 优先从工具调用、命令输出、文件改动中提取事实，不要编造
- 对"已验证"的结论和"推断"的结论分开表述
- 如需确认当前状态，可运行只读命令（`git status`、`git log --oneline -5` 等）

### 第 3 步：按模板写入文件

用 `date +%Y-%m-%d` 获取日期，文件命名：`YYYY-MM-DD_<kebab-case-问题描述>.md`

```markdown
# [问题标题]

**日期**: YYYY-MM-DD
**相关组件/模块**: [组件名称]
**状态**: 已解决 / 部分解决 / 未解决

## 问题描述
清晰描述遇到的问题——什么不工作，预期行为是什么。

## 症状与错误信息
具体的错误消息、异常行为、最小复现步骤。

## 根本原因分析
为什么会发生？深入到根因，不要只写表面现象。

## 解决方案
最终走通的干净步骤序列，可直接复现。

## 验证方法
如何确认问题已解决。

## 关键学习经验
从这次调试中得到的非显而易见的教训。

## 预防措施（可选）
如何避免类似问题再次发生。

## 弯路记录（可选）
- **试过**: <做了什么> — **结果**: <为什么没走通> — **教训**: <结论>

## 相关资源
相关代码文件、配置、文档链接等。
```

### 第 4 步：确认

写完后向用户报告：文件路径、问题状态、关键学习经验摘要（1-2 句）。不要复述全文。

## 安全与质量约束

- **不泄密**：密钥、token、`.env` 内容用键名引用（`API_KEY=<redacted>`），绝不写明文值
- **诚实记录**：状态如实标；未解决的问题在"解决方案"一节写明"尚未找到根本解决方案"
- **弯路要有结论**：每条弯路都落到"教训"，不写只是流水账
- **精炼**：只记有价值的内容；显而易见的试错不必记
- **不覆盖**：每次生成新的时间戳文件，绝不覆盖已有文件

## 与其他 skill 的关系

- **save-pipeline-memory**：关注"工作流程的固化"；本 skill 关注"单个问题的调试经验"。
  两者可配合：save-pipeline-memory 的"弯路与经验"里若有重要 bug，可用本 skill 单独沉淀。
- **debug-experience-system**：用于**建立**整套调试知识库体系（目录规范、团队流程等）；
  本 skill 用于**日常记录**单次调试经验。
