---
name: interactive-concept-tutor
description: Use when the user wants to *learn* or *understand* a technical concept (an algorithm, a math derivation, an ML architecture, a systems internal) rather than just get a one-shot answer — triggers include "explain X", "teach me X", "help me understand X", or being stuck on a concept while reading a paper or code. Probe the user's level with a few questions FIRST, then teach interactively through a runnable Jupyter notebook with LaTeX derivations and small experiments.
---

# Interactive Concept Tutor

教学不是把答案倒给用户,而是先摸清对方站在哪里,再用可运行、可改的 notebook 带对方一步步推导。两条经验驱动这个 skill:

1. **先提问探测水平** —— 有奇效。同一个概念对新手和专家要讲得完全不同,不探测就大概率讲错深度。
2. **Jupyter Notebook 交互** —— LaTeX 讲清"为什么",可运行代码让用户"亲眼看到"机制,而不是被动读文字。

## When to use

- 用户说"讲讲 / 教我 / 帮我理解 X"
- 用户想吃透某个算法、数学推导、模型架构、系统原理
- 用户在读论文或代码,卡在某个概念上

**不适用**:用户只要一个事实性答案、只要修 bug、只要写代码完成任务 —— 那就直接做,别启动教学流程。

## Workflow

### Phase 0 — 探测水平(必做,不可跳过)

在写任何内容之前,先问 2–4 个问题。这是整个 skill 效果的关键。目标是定位用户的"最近发展区":他已经会什么,下一步能接住什么。

问题应覆盖:
- **背景锚点**:相关前置概念熟不熟?(例:教线性 attention 前,先探 softmax attention / RNN 的掌握度)
- **目标深度**:要到什么程度?(建立直觉?能自己推导?能动手实现?)
- **触发点**:为什么现在学?(在读某篇论文?看某段代码?)

模板见 `references/check-questions.md`。**等用户回答后**再进入 Phase 1,不要自问自答。

### Phase 1 — 规划教学路径

根据回答列出章节大纲,采用**演进式**结构:从用户已知的起点出发,一步步推到目标。每一节回答一个"为什么"—— 为什么需要它、上一步的缺陷是什么。跟用户快速确认大纲后再动手。

### Phase 2 — 生成 notebook

**用 `jupyter-notebook` skill 来生成 `.ipynb`** —— 它有模板和 `new_notebook.py` 脚本,避免手写 notebook JSON 出错。本 skill 只负责教学内容的组织,不重复造生成机制。

内容组织原则:

- **markdown cell 讲原理**:用 LaTeX 写数学。注意在 Python 生成脚本里用 raw string(`r"""..."""`)避免反斜杠被转义吃掉。
- **code cell 让用户亲眼看到**:每引入一个关键公式或算法,配一段小 numpy/torch 实验。
  - 用 `assert` / `np.allclose` 验证"两种写法等价"(例:递推形式 ≡ 直接求和)。
  - 打印中间变量(遗忘因子、状态范数、误差项)让抽象的机制变具体。
  - cell 要小、聚焦、可独立运行,输出简短。
- **收尾节**:画出演进链(A 的缺陷 → B 如何补 → C 再补),并指明下一步能学什么。

生成后,若环境允许就跑一遍 top-to-bottom 验证无误;跑不了就明确告知用户如何在本地验证。

### Phase 3 — 交互跟进

交付 notebook 不是终点。主动邀请用户改参数、跑 cell、提问。用**检验性提问**确认对方是否真懂,而不是假装懂 —— 维度和题库见 `references/check-questions.md`。根据反馈补充 cell 或调整深度。

## Reference map

- `references/check-questions.md` —— Phase 0 的水平探测模板 + Phase 3 的检验性提问(直觉/推导/边界/代码对应四个维度),含线性 attention / KDA 的具体范例题库。

## 相关 skill

- `jupyter-notebook` —— 生成和编辑 `.ipynb` 的机制层。本 skill 依赖它产出 notebook。

