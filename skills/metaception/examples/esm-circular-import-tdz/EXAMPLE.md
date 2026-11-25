---
name: esm-circular-import-tdz
description: |
  Fix `Cannot access 'X' before initialization` thrown at runtime under `tsx watch` when two ESM
  modules import each other's named exports. Use when: (1) 报错栈跨 ≥2 个模块且只在运行期出现,
  (2) `npx madge --circular --extensions ts src` 报出环, (3) `tsc --noEmit` 与构建均通过但请求触发即抛错,
  (4) 报错在冷启动首次请求必现、热重载后偶发消失。
author: yanzhou
version: 1.1.0
date: 2026-11-13
---

# ESM 循环导入导致的运行期 TDZ 报错

## Facts

| # | 事实 | 证据 | 复核命令 | 生效条件 | 记录日期 |
|---|------|------|----------|----------|----------|
| F1 | 运行期抛 `Cannot access 'X' before initialization`，栈跨 2 个以上模块 | dev server stderr，2026-11-10 两次复现 | `npm run dev` 后 curl 触发路由 | tsx 4.19, node 20.11, `"type": "module"` | 2026-11-10 |
| F2 | `npx madge --circular --extensions ts src` 报出环路径，而 `tsc --noEmit` 零报错 | madge 输出环 `a.ts > b.ts > a.ts`；tsc exit 0 | `npx madge --circular --extensions ts src && npx tsc --noEmit` | madge 6.1, typescript 5.4 | 2026-11-10 |
| F3 | 把其中一侧改成 `import type` 或函数内动态 `await import()` 后报错消失 | 改后连续 20 次请求 0 报错 | `for i in $(seq 20); do curl -s -o /dev/null -w '%{http_code}\n' localhost:3000/api/x; done` | 同 F1 | 2026-11-10 |
| F4 | 纯 CJS 项目同一根因不抛 TDZ，只表现为导出为 `undefined` | 会话内对照实验：临时改 `require` 后报错消失但值 undefined | `node -e "require('./a.js')"` | node 20.11, 无 `"type": "module"` | 2026-11-10 |

## Model

**机制链**：模块 A 顶层 `import { b } from './b'` → B 顶层反向 `import { a } from './a'` →
ESM 规范要求先完成实例化再求值，A 求值到访问点时 B 的绑定尚未初始化 → 抛 TDZ 错 →
`tsc` 只做类型检查不做求值顺序分析，因此不报错；`madge` 做图分析所以能报环。

**分类树**：
- 循环导入 + ESM 具名导出 → 运行期 TDZ（本技能）
- 单文件内变量声明顺序错误 → TDZ，但栈不跨文件、`madge` 无环
- CJS/ESM 混用 → 导出为 `undefined`，报 `undefined is not a function`
- 构建产物顺序被 bundler 重排 → 只在打包后出现，源码 `madge` 无环

**判别标准**：
| 近似案例 | 可观测区分信号 |
|---|---|
| 单文件声明顺序错误 | 报错栈只含 1 个文件；`madge --circular` 输出 `No circular dependency found` |
| CJS/ESM 混用 | 报错是 `undefined is not a function`，不是 TDZ 文案 |
| bundler 重排 | `npm run dev`（不打包）不报错，只有 `npm run build && npm start` 报错 |

**边界**：仅适用于 ESM（`"type": "module"` 或 `.mts`）。纯 CJS 走 F4 的另一条表现，不适用本技能的修复路径。

## Checks

| # | 纠正 | 形态 | 接线位置 | 检查命令 | 通过判据 | 负控 | 记录日期 |
|---|---|---|---|---|---|---|---|
| X1 | 顶层具名互导重新被引入，构建仍绿但运行期抛 TDZ | lint | `package.json` 的 `scripts.lint:cycles`，由 `.github/workflows/ci.yml` 的 lint job 调用 | `npx madge --circular --extensions ts src` | exit=0，输出 `✔ No circular dependency found!` | 在 `src/b.ts` 还原 `import { a } from './a'` 后 exit=1，输出 `✖ Found 1 circular dependency!  1) a.ts > b.ts > a.ts` | 2026-11-13 |
| X2 | 冷启动首个请求 500，但只有手测才发现 | test | `tests/e2e/tdz.spec.ts`，由 `npm test` 调用 | `npx vitest run tests/e2e/tdz.spec.ts` | exit=0，1 passed | 还原 `src/a.ts` 的顶层具名导入后 exit=1，断言失败信息含 `Cannot access 'x' before initialization` | 2026-11-13 |

**无法自动化的纠正**：

| # | 纠正 | 为何 L1–L7 都不可行 | 退而求其次 | 复审触发 |
|---|---|---|---|---|
| X3 | 打断环时应改"被调用次数少"的一侧，而不是随手改报错那一侧 | 选边依赖模块所有权与调用频度的权衡，没有可判定的机器信号；强行按调用数自动选会在共享工具模块上选错 | 写进 `## Procedure` B1 步骤 2 的判断依据 | 出现能按调用图给出选边建议的工具时重评 |

## Procedure

**前置条件**：能本地复现；当前改动已提交或已 `git stash`；`madge` 可用。

**决策表**：
| 入口观测 | 分支 |
|---|---|
| 栈跨 ≥2 模块 且 `madge` 报环 | B1 打断环 |
| 栈单文件 且 `madge` 无环 | B2 非本技能，见 See also |
| `npm run dev` 正常、打包后报错 | B3 转 bundler 侧排查，本技能不适用 |

**B1 打断环**
1. `npx madge --circular --extensions ts src`
   - 期望：打印环路径，含报错栈里的两个模块
   - 不匹配：转停止条件 S1
2. 选环上"被调用次数少"的一侧，把具名值导入改为 `import type`；若运行期确实需要该值，改为在函数体内 `const { x } = await import('./b')`
   - 期望：`tsc --noEmit` 仍 exit 0
   - 不匹配：说明该值参与顶层求值，转 S2
3. `npm run dev` 后重复触发 20 次
   - 期望：20 个 200，stderr 无 TDZ
   - 不匹配：转 S1

**回滚**：`git checkout -- <被改文件>`（前置条件已保证改动可丢弃）。

**停止条件**：
- S1：`madge` 报 0 环但运行期仍抛 TDZ → 根因不是循环导入，停止本流程，重新定位。
- S2：两侧都在顶层求值对方，30 分钟内无法只改一侧收敛 → 改为依赖注入重构（把共享状态提到第三个模块）。

## Calibration

**逐条置信度**：
| 事实/结论 | 置信度 | 依据 |
|---|---|---|
| F1 | verified | 会话内两次复现，stderr 原文 |
| F2 | verified | 两条命令的真实输出 |
| F3 | verified | 20 次请求计数 |
| F4 | verified | 对照实验 |
| "生产构建（vite build）行为相同" | inferred | 只在 dev 模式验证过 |
| X1 负控 | verified | 还原 `src/b.ts` 后 madge exit=1 |
| X2 负控 | verified | 还原 `src/a.ts` 后 vitest 断言失败 |

**证伪条件**（出现即本技能失效或需重写）：
- `madge` 7.x 改变 `--circular` 对 ESM 的检测语义，导致步骤 1 的期望输出不再成立。
- tsx 切换到原生 ESM loader 后 TDZ 抛出时机变化，F1 的"冷启动必现"不再成立。
- `src/` 布局调整后 X1 的 `--extensions ts src` 不再覆盖全部源码（环会被漏报）。

**未知清单**：
- 未验证 Windows 平台 madge 行为；验证方法：Windows CI 上跑复核命令。
- 未验证 `--conditions` 自定义解析下的表现。

**复审日期**：2027-05-10（到期重跑 F1–F4 的复核命令）

**使用台账**：
| 日期 | 场景 | 结果 |
|---|---|---|
| 2026-11-10 | 首次抽取 | — |

## See also

- [madge 文档](https://github.com/pahen/madge)
- `metaception/resources/skill-template.md`（结构模板）
