---
name: analyze-pr
description: 分析GitHub/GitLab的Pull Request，拉取代码获取diff，读取PR网页描述，生成综合分析文档。当用户提供PR链接并要求分析、审查或总结PR时使用。
allowed-tools: Bash(git *), Bash(gh *), Bash(curl *), Read, Write, Grep, Glob, WebFetch
argument-hint: <PR URL, e.g. https://github.com/owner/repo/pull/123>
---

# 分析 Pull Request

给定一个 PR URL，在本地仓库中拉取代码变更并读取 PR 描述，生成综合分析文档。PR 对应的仓库就是当前本地仓库。

运行 `/analyze-pr <PR_URL>`

## 工作流程

### 第一步：解析 PR URL

从 URL 中提取：

- **平台**：GitHub 或 GitLab
- **Owner/Org**、**Repo**、**PR Number**

支持的格式：

```
https://github.com/{owner}/{repo}/pull/{number}
https://gitlab.com/{owner}/{repo}/-/merge_requests/{number}
```

### 第二步：获取 PR 元信息

优先使用 `gh` CLI（处理认证更方便）：

```bash
# 检查 gh 是否可用
command -v gh >/dev/null 2>&1

# 使用 gh 获取 PR 信息（包括 baseRefName）
gh pr view {number} --repo {owner}/{repo} --json title,body,author,labels,baseRefName,headRefName,additions,deletions,changedFiles,commits,comments,reviews

# 获取 PR diff
gh pr diff {number} --repo {owner}/{repo}
```

如果 `gh` 不可用，使用 `curl` 访问 GitHub API：

```bash
curl -s https://api.github.com/repos/{owner}/{repo}/pulls/{number}
```

从返回数据中获取 `base.ref`（base 分支名）。

### 第三步：拉取 PR 分支到本地

```bash
# GitHub
git fetch origin pull/{number}/head:pr-{number}

# GitLab
git fetch origin merge-requests/{number}/head:mr-{number}
```

不要 checkout PR 分支，只用它作为 ref 进行 diff，避免影响工作区。

### 第四步：生成 Diff

使用第二步获取的 `baseRefName` / `base.ref` 作为 base 分支（不要硬编码 `main`）：

```bash
BASE_BRANCH={baseRefName from step 2}

# 变更文件列表
git diff --name-only origin/$BASE_BRANCH...pr-{number}

# 变更统计
git diff --stat origin/$BASE_BRANCH...pr-{number}

# 完整 diff
git diff origin/$BASE_BRANCH...pr-{number}

# 提交历史
git log --oneline origin/$BASE_BRANCH..pr-{number}
```

### 第五步：分析变更

对每个变更文件理解：

1. **改了什么**：新增、删除、修改
2. **为什么改**：从 commit message、PR 描述和代码上下文推断
3. **影响范围**：涉及哪些组件/模块

按类别分组变更：

- **新功能**：新文件、新函数、新 API
- **Bug 修复**：错误处理、逻辑修正
- **重构**：代码重组、命名变更
- **配置**：构建、CI/CD、依赖变更
- **文档**：README、注释、文档
- **测试**：新增或修改测试

### 第六步：生成分析文档

创建 markdown 文档：

```markdown
# PR 分析: {PR Title}

> PR 链接: {url}
> 作者: {author}
> 日期: {date}
> 分支: {base} ← {head}

## 概述

{一段话概述这个 PR 做了什么以及为什么}

## 变更统计

- 变更文件数: {count}
- 新增行数: {additions}
- 删除行数: {deletions}

## 详细变更

### {类别 1: 如 新功能}

#### {文件或组件名}

- **改了什么**: 变更描述
- **为什么改**: 变更原因
- **关键代码变更**: 重要代码修改的简述

### {类别 2: 如 Bug 修复}

...

## 提交历史

| Hash | Message | Author |
|------|---------|--------|
| {hash} | {message} | {author} |

## PR 讨论要点

{PR 评论和评审中的关键要点}

## 影响评估

- **破坏性变更**: {有/无, 详情}
- **受影响的依赖**: {列表}
- **需要关注的区域**: {列表}

## 审查备注

{额外的观察或建议}
```

### 第七步：保存 Diff 文件

将完整 diff 保存到本地文件：

```bash
git diff origin/$BASE_BRANCH...pr-{number} > pr-{number}.diff
```

这个 `.diff` 文件包含 PR 引入的所有代码变更。

### 第八步：保存分析文档与清理

将分析文档保存到当前工作目录：`pr-analysis-{number}.md`

清理临时分支 ref：

```bash
git branch -D pr-{number}
```

最终输出文件：
- `pr-{number}.diff` — PR 的原始 diff 文件
- `pr-analysis-{number}.md` — 结构化分析文档

## 注意事项

- 优先使用 `gh` CLI，它能自动处理认证
- 如果 diff 非常大（>5000 行），按文件/模块汇总而非逐行分析
- 不要 checkout PR 分支，只用它作为 ref 进行 diff
- 分析完成后务必清理临时分支 ref
- 文档使用中文输出
