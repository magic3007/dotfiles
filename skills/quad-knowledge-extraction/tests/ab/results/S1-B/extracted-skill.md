---
name: vitest-workspace-alias-missing-tsconfig-paths
description: |
  vitest 2.x + pnpm workspace 里测试报 `Error: Failed to load url @acme/core (resolved id: @acme/core). Does the file exist?`，
  而 `pnpm --filter @acme/web dev` 与 `pnpm -w build` 都正常。根因：apps/web 存在 vitest.config.ts 时不再加载
  vite.config.ts，`vite-tsconfig-paths` 插件没进 vitest 的解析链。Use when: (1) vitest 报 Failed to load url
  且目标是 workspace 内部包, (2) dev 与 build 都正常只有测试失败, (3) 被依赖包 package.json 的 main 指向 src 源码。
author: yanzhou (claudeception-quad extraction)
version: 1.0.0
date: 2026-11-10
---

# vitest 在 pnpm monorepo 里解析不到 workspace 内部包（tsconfig paths 插件没挂到 vitest.config.ts）

## Facts

| # | 事实 | 证据 | 复核命令 | 生效条件 | 记录日期 |
|---|------|------|----------|----------|----------|
| F1 | 测试失败时的逐字报错为 `Error: Failed to load url @acme/core (resolved id: @acme/core). Does the file exist?`，抛出点 `src/lib/cart.ts:1:23` | vitest stderr：`FAIL src/lib/cart.test.ts` 后紧跟该行 | `pnpm -F @acme/web test` | vitest 2.1.8, node 20.11.1, pnpm 9.12.3, 仓库根有 pnpm-workspace.yaml | 2026-11-10 |
| F2 | 会话环境版本为 node v20.11.1、pnpm 9.12.3、vitest 2.1.8 | `node -v` / `pnpm -v` / `npx vitest --version` 三条命令输出 | `npx vitest --version` | 同一开发机 | 2026-11-10 |
| F3 | workspace 软链已存在且指向正确：`core -> ../../../../packages/core` | `ls -la apps/web/node_modules/@acme/` 输出该软链行 | `ls -la apps/web/node_modules/@acme/` | pnpm 9.x workspace，install 已执行 | 2026-11-10 |
| F4 | pnpm 依赖图认定 `@acme/core 0.3.1` 是 `@acme/web` 的依赖，链接层无问题 | `pnpm -F @acme/web why @acme/core` 输出 `dependencies:` 加 `@acme/core 0.3.1` | `pnpm -F @acme/web why @acme/core` | pnpm 9.12.3 | 2026-11-10 |
| F5 | `packages/core/package.json` 的 `main` 与 `types` 都指向 `./src/index.ts`（源码，非 dist），且文件里没有 `exports` 字段 | `cat packages/core/package.json` 输出含 `"main": "./src/index.ts"` | `cat packages/core/package.json` | @acme/core 0.3.1 当前版本 | 2026-11-10 |
| F6 | `apps/web/vite.config.ts` 第 3 行 import、第 7 行使用 `vite-tsconfig-paths`，而 `apps/web/vitest.config.ts` 只有 `test.environment: 'jsdom'`，无 plugins/alias | `grep -n "tsconfigPaths\|alias" apps/web/vite.config.ts` 输出第 3、7 行；`cat apps/web/vitest.config.ts` 全文无 plugins | `grep -n "tsconfigPaths" apps/web/vite.config.ts apps/web/vitest.config.ts` | vite 5 + vitest 2.1.8 双配置文件布局 | 2026-11-10 |
| F7 | `apps/web/tsconfig.json` 里 `"paths": { "@acme/core": ["../../packages/core/src/index.ts"] }` 确实存在，即映射数据本身没缺 | `cat apps/web/tsconfig.json` 的 paths 段 | `cat apps/web/tsconfig.json` | 该仓库当前 tsconfig | 2026-11-10 |
| F8 | 在 `apps/web/vitest.config.ts` 的 `defineConfig` 里加 `plugins: [tsconfigPaths()]` 后测试通过：`✓ src/lib/cart.test.ts (7 tests) 312ms` | `pnpm -F @acme/web test` 修复后输出 | `pnpm -F @acme/web test` | vitest 2.1.8, vite-tsconfig-paths 已安装于 apps/web | 2026-11-10 |
| F9 | 清掉 vite 缓存后重跑仍通过（`298ms`），说明 F8 不是缓存假象 | `rm -rf apps/web/node_modules/.vite` 后 `pnpm -F @acme/web test` 输出 7 tests 通过 | `rm -rf apps/web/node_modules/.vite && pnpm -F @acme/web test` | 同上 | 2026-11-10 |
| F10 | 修复前先跑 `pnpm -w build` 不改变报错，一个字都不变，因此“缺构建产物”不是本例根因 | 会话尝试 2：根目录 `pnpm -w build` 成功后重跑测试，报错与 F1 完全一致 | `pnpm -w build` 后执行 `pnpm -F @acme/web test` | packages/core 的 main 指向 src 时 build 产物与解析无关 | 2026-11-10 |
| F11 | 同一份代码 `pnpm --filter @acme/web dev` 起服务完全正常、`pnpm -w build` 也成功，只有 vitest 失败 | 会话现象段记录：dev 正常且浏览器页面可跑，build 成功 | `pnpm --filter @acme/web dev` | vite dev 走 vite.config.ts，vitest 走 vitest.config.ts | 2026-11-10 |

## Model

**机制链**：`@acme/core` 是 workspace 内部包，其 `package.json` 的 `main` 指向 `./src/index.ts`（TS 源码）→
pnpm 软链让 node_modules 里能找到包目录，但包内没有可直接被解析的 JS 入口 →
vite dev 之所以能跑，是因为 `apps/web/vite.config.ts` 挂了 `vite-tsconfig-paths()`，它把 `@acme/core`
按 `apps/web/tsconfig.json` 的 `paths` 重写成 `../../packages/core/src/index.ts` → vitest 在检测到
`apps/web/vitest.config.ts` 时以它为唯一配置源、不再合并 `vite.config.ts` → 插件缺席，`paths` 映射无人执行 →
解析器退回裸包解析，命中包名但拿不到入口 → 报 `Failed to load url @acme/core (resolved id: @acme/core)` →
根因是**配置入口分裂**（两个配置文件各管一条解析链），不是链接缺失、也不是构建产物缺失。

**分类树**（同一句 `Failed to load url` / `Cannot find module` 的不同根因）：
- 根因 A：vitest 配置入口分裂，`vite-tsconfig-paths` 只挂在 `vite.config.ts`（本技能覆盖）。
- 根因 B：被依赖包 `main`/`exports` 指向 `dist/`，而 `dist/` 未构建（构建顺序问题）。
- 根因 C：pnpm install 未执行或软链被删，node_modules 里根本没有该包。
- 根因 D：`paths` 映射本身写错或缺 baseUrl，插件在也无法命中。
- 根因 E：包名与目录名不一致（`package.json` 的 `name` 与 import 说明符不匹配）。

**判别标准**：
| 近似案例 | 可观测区分信号 |
|---|---|
| 根因 B 构建产物缺失 | 被依赖包 `package.json` 的 `main` 指向 `./dist/...` 且带 `exports`；`ls packages/core/dist` 报不存在；此时在 vitest.config.ts 加 tsconfigPaths 无效 |
| 根因 C 链接缺失 | `ls -la apps/web/node_modules/@acme/` 没有该软链；`pnpm -F @acme/web why @acme/core` 无输出 |
| 根因 D 映射写错 | `apps/web/tsconfig.json` 的 `paths` 目标路径 `ls` 不存在；加插件后仍报同一错 |
| 根因 A（本技能） | `vite.config.ts` 有 `tsconfigPaths()`、`vitest.config.ts` 无 plugins，且 F3/F4/F7 三项全部正常 |

**边界**：不适用于 vitest 1.x 以前的配置合并行为；不适用于没有 `vitest.config.ts`（此时 vitest 直接复用 `vite.config.ts`，根因 A 不成立）；不适用于包入口是纯 JS/CJS 且已构建的场景（那时裸解析本就能成功）；不覆盖 `vitest --workspace` 多包模式的配置继承（未验证）。

## Procedure

**前置条件**：能在本地复现该测试失败；当前改动已提交或已 stash（后面要改配置文件）；`vite-tsconfig-paths` 已作为 `apps/web` 的 devDependency 安装。

**决策表**：
| 入口观测 | 分支 |
|---|---|
| `vitest.config.ts` 存在且无 plugins/alias，`vite.config.ts` 有 `tsconfigPaths()` | B1 挂插件 |
| 被依赖包 `main`/`exports` 指向 `dist/` 且 `dist/` 不存在 | B2 修构建顺序（本技能不适用，见 See also） |
| `node_modules/@acme/` 下无软链或 `why` 无输出 | B3 重装依赖（本技能不适用） |
| 无 `vitest.config.ts`（vitest 复用 vite.config.ts） | B4 根因 A 不成立，重新定位 |

**B1 把 tsconfigPaths 挂进 vitest 配置**
1. `grep -n "tsconfigPaths" apps/web/vite.config.ts apps/web/vitest.config.ts`
   - 期望：只在 `vite.config.ts` 命中（第 3 行 import、第 7 行使用），`vitest.config.ts` 零命中
   - 不匹配：两个文件都有 → 根因 A 不成立，转停止条件 S1
2. `cat apps/web/tsconfig.json` 并确认 `paths` 里 `@acme/core` 的目标文件真实存在
   - 期望：`paths` 命中且目标 `.ts` 文件 `ls` 得到
   - 不匹配：映射本身错 → 转分支 B4 重新定位
3. 编辑 `apps/web/vitest.config.ts`，在 `defineConfig` 里加 `plugins: [tsconfigPaths()]`（保留原有 `test` 字段）
   - 期望：文件里同时出现 `tsconfigPaths()` 与原 `test` 配置
   - 不匹配：若 `vite-tsconfig-paths` 未安装会 import 失败 → 先在 `apps/web` 装 devDependency 再重试
4. `pnpm -F @acme/web test`
   - 期望：`✓ src/lib/cart.test.ts (7 tests)`，`Test Files 1 passed (1)`
   - 不匹配：仍报 `Failed to load url` → 转停止条件 S1
5. `rm -rf apps/web/node_modules/.vite && pnpm -F @acme/web test`
   - 期望：仍然通过（证明不是缓存假象）
   - 不匹配：清缓存后失败 → 转停止条件 S2

**回滚**：`git checkout -- apps/web/vitest.config.ts`（前置条件已保证改动前是干净的）；若顺带装了依赖，用 `git checkout -- apps/web/package.json pnpm-lock.yaml` 后 `pnpm install` 复原。

**停止条件**：
- S1：按 B1 挂上插件后报错一字不变 → 根因不是配置入口分裂（大概率是被依赖包 `dist` 未构建），停止本路径，按判别标准表重新分流。
- S2：清缓存后回归失败、或改动引出新的解析错误且 30 分钟内无法收敛 → 放弃改配置，改为在 `vitest.config.ts` 里写显式 `resolve.alias` 硬映射，或升级为人工复核 vitest 版本行为。
- S3：需要动 `pnpm-workspace.yaml` 或根 `tsconfig` 才能让插件生效 → 超出本技能范围，升级为人工决策。

## Calibration

**逐条置信度**：
| 事实/结论 | 置信度 | 依据 |
|---|---|---|
| F1、F2 | verified | 会话内命令原始输出 |
| F3、F4、F5、F6、F7 | verified | 会话内 cat/grep/ls/why 命令输出 |
| F8、F9 | verified | 修复后两次测试通过，第二次已清 vite 缓存 |
| F10、F11 | verified | 会话内实测对照（build 后报错不变、dev 正常） |
| 「存在 vitest.config.ts 时 vitest 不合并 vite.config.ts」 | verified | 由 F6 的配置差异加 F8/F11 的行为差异共同证实 |
| 「同事 CI 上的同一报错是同一根因」 | inferred | 只有转述，会话内未在 CI 复现 |
| 「vitest --workspace 多包模式下同样是这个根因」 | inferred | 未跑过该模式 |
| 「对照仓库那次是构建顺序问题、加 tsconfigPaths 无效」 | inferred | 来自会话末尾的另一次经历描述，本会话无命令输出佐证，仅用作判别线索 |
| 「CI 用 `pnpm -F @acme/web test --run` 无 jsdom 差异」 | assumed | 转述的 CI 命令行，未验证 |

**证伪条件**（出现即本技能失效或需重写）：
- vitest 改为在存在 `vitest.config.ts` 时仍自动合并 `vite.config.ts`（合并语义变化），此时根因 A 不再成立。
- vitest 3.x 及以上调整配置解析优先级或弃用 `defineConfig` 的 plugins 透传。
- `vite-tsconfig-paths` 改为自己读取 vitest 配置、或 vitest 内置 tsconfig paths 支持。
- 目标包改为发布 `exports` 且 `main` 指向已构建 JS：裸解析成功，本技能整条路径失效。

**未知清单**：
- CI 环境是否同根因：未验证。将来验证法：在 CI 上按 B1 步骤 3 加插件后重跑 `pnpm -F @acme/web test --run`，看是否转为通过。
- `vitest --workspace`（vitest 2.x 多包模式）下配置继承行为：未验证。将来验证法：建最小双包 workspace 复现本例。
- 非 jsdom 环境（`environment: 'node'`）是否表现一致：未验证，本例只跑过 jsdom。
- Windows / 非 pnpm（npm、yarn workspaces）下软链与解析表现：未验证。

**复审日期**：2027-05-10（到期重跑 Facts 里 F1、F6、F8、F9 的复核命令）。

**使用台账**：
| 日期 | 场景 | 结果 |
|---|---|---|
| 2026-11-10 | 首次抽取（来源会话 S1：pnpm monorepo + vitest 2.1.8） | — |

## See also

- `claudeception/examples/typescript-circular-dependency`（同域不同根因：循环依赖导致的解析/初始化报错，判别看报错是否为 TDZ 而非 `Failed to load url`）。
- 官方文档：vitest 配置（`vitest.config.ts` 与 `vite.config.ts` 的关系）、`vite-tsconfig-paths` README。
