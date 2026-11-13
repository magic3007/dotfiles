---
name: repo-industrialize
description: 系统性整理本地代码仓库并沉淀规范：盘点现状、删除过时代码与文本、确立单一真相源、按工业级标准整改、降低无 agent 用户的修改门槛、把历史对话里的每一条纠正转成确定性检查（lint/测试/CI/脚本），最后产出该 repo 的流程、spec、规范文档与本地 skill。当用户说"整理一下这个仓库""清理过时代码""代码要工业级""统一真相源""把我之前纠正过你的点固化下来""给这个 repo 写规范/流程/spec""repo cleanup""codebase hygiene""make this production-grade"时，即使没有点名本 skill 也要使用它。
---

# Repo Industrialize

把一个长期有人用、但积累了重复文档、死代码和口头约定的仓库，整理成"新人不靠 agent 也能改对"的状态。

核心判断：**约定只写进文档就等于没有**。文档会漂、会被绕过、不会在改坏时报警。所以本 skill 的产物重心不是更多文字，而是一组会失败的检查，加上一份不复述代码的索引型规范。

## 产物层级（先定这个，后面每一步都靠它防止双真相源）

| 层 | 位置 | 只放什么 | 禁止 |
| --- | --- | --- | --- |
| 强制层 | `.repo-std/checks/` + CI | 能跑、能失败的检查 | 无法执行的建议 |
| 台账层 | `.repo-std/corrections.yml` | 每条纠正 → 哪个检查守它 | 以"写进文档了"结案 |
| 规范层 | `docs/REPO_GUIDE.md` | 流程、spec、决策理由、改动路径 | 复述代码里已有的事实 |
| 索引层 | `AGENTS.md`、本地 skill | 指针与命令 | 规范正文的第二份副本 |

同一事实只在一层出现。规范层要陈述代码事实时，写路径指过去，不抄内容。

## 适用与不适用

适用：有真实历史、有人继续维护、已经出现"同一件事两种说法"的仓库。
不适用：一次性脚本、临时实验目录、vendored 的第三方源码树（只管边界，不整改内部）。

按规模裁剪，不要对小仓库做大阵仗：百来个文件的仓库，阶段 1 与 2 合成一轮（盘点报告直接读、不落盘），检查先做三五条最常犯的；上千文件的仓库按 [references/edge-cases.md](references/edge-cases.md) 分片，并且先把闸门接上再整改，防止一边整理一边回潮。阶段 5 的纠正台账在任何规模下都不省——它是这套流程唯一不可替代的部分。

---

## 阶段 0：建立绿基线

没有可复现的绿状态，后面每一次删除都是赌博。

- **输入**：仓库根目录、README/CI 配置里的构建与测试命令。
- **操作**：找出构建、测试、lint 的真实命令并实跑一次；记录耗时与失败项；确认工作区干净（`git status`）、确认当前分支与远端关系。命令跑不起来时，先修到能跑，这本身就是第一批整改。
- **产物**：一行可复制的基线命令清单（后面写进 `docs/REPO_GUIDE.md` 的"验证"节）；基线运行结果。
- **验收**：基线命令全绿，或已明确记录"原本就红"的用例清单；工作区干净。

## 阶段 1：仓库现状盘点

- **输入**：阶段 0 的干净工作区。
- **操作**：

  ```bash
  python <skill-dir>/scripts/inventory.py --root . \
      --out .tmp/docs/repo-inventory.md --json .tmp/docs/repo-inventory.json
  ```

  脚本给出：分类统计、体量离群、内容完全重复、同名不同路径、文档标题跨文件重复、悬挂引用、无人引用文件、陈旧标记。它只产生**线索**，不产生结论。把线索逐条读完，并补上脚本看不到的东西：谁在用这个仓库、哪些目录是生成物、哪些是 vendored。

- **产物**：`.tmp/docs/repo-inventory.md`（临时工作文档，整理结束即删）。
- **验收**：报告里每个非空小节都被人读过，并在清理计划里有对应裁决或显式"保留"。

## 阶段 2：过时内容清理与单一真相源

- **输入**：盘点报告。
- **操作**：对每个候选走 [references/ssot.md](references/ssot.md) 的三问判据（谁在引用、哪份更新、删掉会不会有人发现）。文档冲突时按该文件的仲裁顺序定唯一真相源，其余改成指针或删除。删除走独立提交，与功能改动分开，便于回滚。
- **产物**：一组"只删不改"的提交；被选定的真相源文件；指针替换后的文档。
- **验收**：阶段 0 的基线命令仍全绿；`inventory.py` 重跑后重复项、悬挂引用归零或每项有记录的豁免理由。

## 阶段 3：工业级代码整改

- **输入**：清理后的代码树。
- **操作**：按 [references/quality-bar.md](references/quality-bar.md) 逐条对照：错误处理、边界与失败路径、命名、模块职责与体量、依赖收敛、测试是否覆盖会出事的分支。先修"会让人改错"的结构问题，再修风格问题。每修一类问题立刻问：这类问题能不能变成检查？能就进阶段 5。
- **产物**：结构整改提交（每个提交单一关切、可独立回滚、可编译可运行）。
- **验收**：基线命令全绿；新增或修改的行为有对应测试；没有留下 TODO 占位、注释掉的旧实现、被绕过的兼容分支。

## 阶段 4：降低修改门槛

目标读者是没有 code agent、没读过本仓库的人。他要在十分钟内知道"改一个行为该动哪里、怎么验证"。

- **输入**：整改后的代码树、阶段 0 的基线命令。
- **操作**：写出 3–5 条**最小改动路径**（典型任务 → 入口文件 → 要改的函数 → 验证命令），放进 `docs/REPO_GUIDE.md`。入口不好找时，解决办法是改代码结构或命名，而不是写更长的说明。按 quality-bar 的"可改性"小节检查：目录名是否自解释、配置是否集中、是否存在隐式魔法。
- **产物**：`docs/REPO_GUIDE.md` 的"改动路径"与"验证"两节。
- **验收**：按文档里的路径真正走一遍一个小改动（可以是无害改动后回滚），命令与路径与事实一致。

## 阶段 5：纠正转检查（本 skill 的核心）

把"你以前纠正过我"的每一条，变成一条会失败的检查。做法见 [references/correction-to-check.md](references/correction-to-check.md)，这里是流程：

- **输入**：历史对话中的纠正、code review 意见、`AGENTS.md`/`CLAUDE.md` 里现存的口头约定、阶段 3 反复出现的问题。
- **操作**：
  1. 逐条列出纠正，写成可判定的一句话规则（"src 下不得有行内注释"，而不是"代码要干净"）。
  2. 为每条选强制手段：`script` / `lint` / `test` / `ci`。选不出来时走 correction-to-check.md 的降级阶梯，最后才允许 `waived`，且必须填豁免理由、暴露位置、复查日期。
  3. 写检查，并写一份**违规样本**（fixture），用它证明检查真的会失败。
  4. 登记台账：

     ```bash
     python <skill-dir>/scripts/corrections.py --ledger .repo-std/corrections.yml add \
       --origin "2026-11-10 对话：用户指出 src 下不该有行内注释" \
       --rule "src/ 下不得出现行内注释" \
       --kind script \
       --run   "python3 .repo-std/checks/no_inline_comments.py src" \
       --prove "python3 .repo-std/checks/no_inline_comments.py .repo-std/checks/fixtures/no_inline_comments"
     ```

     台账 schema 直接拒绝 `kind: doc`/`review`：文档不是强制手段。
  5. 接 CI：让流水线跑 `corrections.py verify`、`corrections.py run`，以及 `prove` 做反向验证。目标仓库要独立于本 skill 运行时，把 `corrections.py` 复制进去（例如 `.repo-std/vendor/`），并在台账或 `docs/REPO_GUIDE.md` 记下来源路径与 sha256——复制件不记来源就变成第二个真相源。CI 只调一个固定入口（`.repo-std/gate.sh` 或 `make check`），别让每条流水线各写各的路径。

- **产物**：`.repo-std/corrections.yml`、`.repo-std/checks/*`、fixtures、CI 配置改动。
- **验收**：

  ```bash
  python <skill-dir>/scripts/corrections.py --ledger .repo-std/corrections.yml verify  # schema 与豁免复查日期
  python <skill-dir>/scripts/corrections.py --ledger .repo-std/corrections.yml run    # 干净仓库上全部 exit 0
  python <skill-dir>/scripts/corrections.py --ledger .repo-std/corrections.yml prove  # 违规样本上全部非 0
  ```

  三条全过，且每条 enforced 纠正都能说出"它会在什么情况下让 CI 红"。

## 阶段 6：产出流程与规范文档 + 本地 skill

- **输入**：前五阶段的事实。
- **操作**：用 [assets/templates/REPO_GUIDE.md](assets/templates/REPO_GUIDE.md) 写 `docs/REPO_GUIDE.md`——它是规范正文的唯一所在。再用 [assets/templates/repo-skill.md](assets/templates/repo-skill.md) 生成 `.agents/skills/<repo>-workflow/SKILL.md`：只写触发条件、命令清单、指向 REPO_GUIDE 的指针，不抄正文。最后把根 `AGENTS.md` 收成指针。
- **产物**：`docs/REPO_GUIDE.md`、本地 skill、瘦身后的 `AGENTS.md`。
- **验收**：在 REPO_GUIDE 里随机抽三条陈述，都能在代码或检查里找到对应事实；本地 skill 与 REPO_GUIDE 没有任何重复段落；盘点脚本重跑，`shared_doc_headings` 不再出现规范类标题跨文件重复。

---

## 最终交付物清单

1. `.tmp/docs/repo-inventory.md` — 盘点报告，收尾时删除（结论已落到提交与文档里）。
2. 清理提交序列 — 删除与合并，各自独立可回滚。
3. 整改提交序列 — 每个单一关切，基线命令全绿。
4. `.repo-std/corrections.yml` — 纠正台账，enforced 条目全部有检查，waived 条目全部有复查日期。
5. `.repo-std/checks/` — 检查脚本 + 违规样本 fixtures。
6. CI 接线 — `corrections verify/run` 进流水线。
7. `docs/REPO_GUIDE.md` — 流程、spec、规范、改动路径、验证命令的唯一正文。
8. `.agents/skills/<repo>-workflow/SKILL.md` — 索引型本地 skill。
9. 瘦身后的根 `AGENTS.md` — 只剩指针。

## 边界与例外（指针）

判不准是否过时、纠正无法自动化、仓库太大、文档互相矛盾、生成物与 vendored 目录等，按 [references/edge-cases.md](references/edge-cases.md) 处理。通用原则：不确定就不删，但必须把不确定本身变成一条带复查日期的记录，而不是沉默保留。

## 命令速查

```bash
SKILL=<skill-dir>
python $SKILL/scripts/inventory.py --root . --out .tmp/docs/repo-inventory.md
python $SKILL/scripts/corrections.py --ledger .repo-std/corrections.yml verify
python $SKILL/scripts/corrections.py --ledger .repo-std/corrections.yml run
python $SKILL/scripts/corrections.py --ledger .repo-std/corrections.yml prove
python $SKILL/scripts/corrections.py --ledger .repo-std/corrections.yml list
```

`<skill-dir>` 是本 SKILL.md 所在目录。`corrections.py` 需要 PyYAML；`inventory.py` 只用标准库。
