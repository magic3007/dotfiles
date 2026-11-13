生成到 `<repo>/.agents/skills/<repo>-workflow/SKILL.md`（文件名必须是 `SKILL.md`）。

本地 skill 是索引层：只放触发条件、命令、指针。规范正文留在 `docs/REPO_GUIDE.md`，这里一个字都不抄，否则两边必然漂移。

---

```markdown
---
name: <repo>-workflow
description: 在 <repo> 仓库里开发、改动或评审时使用：给出该仓库的入口地图、改动路径、验证命令与必须遵守的确定性检查。当用户在这个仓库里说要加功能、修 bug、改配置、提交前检查、或问"这个该改哪里"时使用。
---

# <repo> 工作流

规范正文在 [docs/REPO_GUIDE.md](../../../docs/REPO_GUIDE.md)。本文件只给路由。

## 动手前

1. 读 `docs/REPO_GUIDE.md` 的"目录地图"与"改动路径"，确认改动落点。
2. 工作区必须干净：`git status`。

## 改动中

- 按 `docs/REPO_GUIDE.md` 的"规范"节作业；该节每条都标了守它的检查。
- 一个提交一个关切，每个提交可编译、可运行。

## 提交前（必须全过）

```bash
<构建命令>
<测试命令>
python <corrections.py 路径> --ledger .repo-std/corrections.yml verify
python <corrections.py 路径> --ledger .repo-std/corrections.yml run
```

## 收到新的纠正时

不要只改文档。按 `docs/REPO_GUIDE.md` 的"确定性检查"节：写成可判定规则 → 写检查与违规样本 → `corrections.py add` 登记 → 接 CI。

## 本仓库的雷区

- <只列会让人改错的事实，每条一行，带路径。>
```
