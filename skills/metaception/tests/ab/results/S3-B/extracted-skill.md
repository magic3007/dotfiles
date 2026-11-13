---
name: github-actions-node-modules-cache-poisoning
description: |
  GitHub Actions 上 CI 必失败、本地永远全绿：`actions/cache` 缓存整个 `node_modules` 且用 `restore-keys`
  前缀兜底，恢复出旧依赖（`@acme/pricing@1.8.3`），而 workflow 缺 `npm ci`。报错形如
  `AssertionError: expected 1999 to be 2000`、`FAIL  test/billing.spec.ts`。
  Use when: (1) 同一 commit 重跑 CI 必挂但本地 `npm test` 连续多次全绿, (2) CI 里 `npm ls <pkg>`
  打印的版本与 `package-lock.json` 不一致, (3) workflow 同时存在 `actions/cache` 的
  `path: node_modules` 与 `restore-keys` 前缀兜底, (4) 只改测试文件的 PR 突然让 CI 变红。
  修法：只缓存 `~/.npm`、删掉 `restore-keys`、显式加 `npm ci`。
author: yanzhou (claudeception-quad extraction from session S3)
version: 1.0.0
date: 2026-11-10
---

# GitHub Actions node_modules 缓存污染导致 CI 必失败

## Facts

| # | 事实 | 证据 | 复核命令 | 生效条件 | 记录日期 |
|---|------|------|----------|----------|----------|
| F1 | `actions/cache@v4` 的 `restore-keys` 是前缀匹配，只要前缀命中就恢复旧缓存，与 `hashFiles('package-lock.json')` 是否变化无关 | 会话内 CI 实测恢复到 1.8.3 时代的 `node_modules`：CI 打印 `@acme/pricing@1.8.3`，本地 `npm ls @acme/pricing` 打印 `@acme/pricing@1.9.0` | 在 `actions/cache` 步骤之后、`npm test` 之前插一步 `npm ls @acme/pricing` 并读 CI 日志 | actions/cache@v4, ubuntu-24.04 runner, npm 10.8.2, node 20.11.1 | 2026-11-10 |
| F2 | workflow 缺 `npm ci` 时，`actions/setup-node@v4` 的 `cache: 'npm'` 只缓存 npm 下载缓存（`~/.npm`），不负责安装依赖 | 会话内 CI 在恢复缓存后直接 `npm test`，实际跑在 `@acme/pricing@1.8.3` 上 | `grep -n "npm ci" .github/workflows/ci.yml`（无输出即缺安装步骤） | actions/setup-node@v4, cache: 'npm' | 2026-11-10 |
| F3 | 本案 lockfile 与 package.json 一致，因此“依赖版本漂移”不能由 lockfile 解释 | `grep -n '"@acme/pricing"' package.json package-lock.json` → `package.json:12: "@acme/pricing": "^1.9.0"` 与 `package-lock.json:141: "node_modules/@acme/pricing": { "version": "1.9.0"` | `grep -n '"@acme/pricing"' package.json package-lock.json` | npm lockfileVersion 3 | 2026-11-10 |
| F4 | 在 CI 内 `rm -rf node_modules && npm ci` 把版本拉回 `1.9.0` 并让 `npm test` 通过 | 会话内 CI 临时加两步后的输出 `@acme/pricing@1.9.0`，随后 `npm test` 通过 | `rm -rf node_modules && npm ci && npm ls @acme/pricing && npm test` | npm 10.x, 有 `package-lock.json` | 2026-11-10 |
| F5 | 修复形态是：`actions/cache` 的 `path` 改为 `~/.npm`、删掉 `restore-keys`、显式 `- run: npm ci` | 会话内改完后连续 6 个 commit（含两个只改测试文件的 commit）CI 全绿，本地 `rm -rf node_modules && npm ci && npm test` 也绿 | `rm -rf node_modules && npm ci && npm test` 后推一个只改测试文件的 commit 看 CI | actions/cache@v4, npm 10.x | 2026-11-10 |
| F6 | 失败是确定性的，不是 flake：同一 commit 重跑必失败，本地 `npm test` 连续 20 次全绿 | 会话记录“CI 上重跑同一个 commit 也是必失败（不是 flake）”与本地 20 次全绿 | `for i in $(seq 1 20); do npm test; done` | vitest, node 20.11.1 | 2026-11-10 |
| F7 | CI 报错串是 `AssertionError: expected 1999 to be 2000`，位置 `test/billing.spec.ts:42:20`；根因是依赖版本而非断言文案 | CI 输出 `FAIL  test/billing.spec.ts` 与 ` ❯ test/billing.spec.ts:42:20`；`git diff` 确认本次只改字符串字面量 | `npx vitest run test/billing.spec.ts` | vitest, acme-api@2.4.0 | 2026-11-10 |
| F8 | 上一个 commit 在 CI 是绿的，而本次 PR 只改了 `test/billing.spec.ts` 的断言文案，说明“改了测试才红”是相关不是因果 | 会话记录的现象描述与 `git diff` 结果 | `git diff HEAD~1 -- test/billing.spec.ts` | 任意 git 仓库 | 2026-11-10 |

## Model

**机制链**：CI 必失败而本地永远绿 → 差异只可能来自依赖树或环境 → workflow 用 `actions/cache` 缓存整个 `node_modules`，并给了 `restore-keys: ${{ runner.os }}-nm-` 前缀兜底 → `hashFiles('package-lock.json')` 已变但前缀仍命中，旧缓存被恢复 → workflow 里没有 `npm ci`，`setup-node` 的 `cache: 'npm'` 只管 `~/.npm` 下载缓存 → 测试跑在 1.8.3 时代的 `node_modules` 上 → billing 断言拿到旧定价 → 抛 `AssertionError: expected 1999 to be 2000`。本地没有缓存恢复这一步，所以本地永远绿。

**分类树**（同症状“CI 挂、本地绿”的不同根因）：
- 根因 A：缓存恢复出旧 `node_modules`，且 workflow 缺显式安装步骤（本案）。
- 根因 B：lockfile 里的 tarball integrity 与 registry 实际发布不一致（上游重发同版本），报 `npm ERR! code EINTEGRITY`。
- 根因 C：环境差异（时区、locale、Node 版本、runner 镜像版本）。
- 根因 D：真 flake（并发、定时、随机种子）。

**判别标准**：
| 近似案例 | 可观测区分信号 |
|---|---|
| 根因 A 缓存污染（本案） | CI 里 `npm ls <pkg>` 版本 ≠ `package-lock.json` 版本；workflow 同时有 `path: node_modules` 与 `restore-keys` 前缀 |
| 根因 B integrity 不一致 | 报错串是 `npm ERR! code EINTEGRITY` 与 `integrity checksum failed when using sha512`；`npm ls` 版本与 lockfile 一致；删 `restore-keys` + `npm ci` 无效 |
| 根因 C 环境差异 | 依赖版本一致；换 `TZ=UTC` 或换 runner 版本后行为变化 |
| 根因 D 真 flake | 同一 commit 重跑结果不稳定（本案重跑必挂，可直接排除） |

**边界**：只适用于 npm + GitHub Actions 且 workflow 缓存了 `node_modules` 的场景。不适用于本地也失败的场景、不适用于依赖版本已与 lockfile 一致的场景；pnpm（`cache: 'pnpm'`）与 yarn 未实测，不适用。

## Procedure

**前置条件**：能修改 `.github/workflows/*.yml` 并推 commit 触发 CI；已确认失败是确定性的（同一 commit 重跑必挂）；当前改动已提交或已 stash。

**决策表**：
| 入口观测 | 分支 |
|---|---|
| CI 里 `npm ls <pkg>` 版本 ≠ `package-lock.json` 版本 | B1 清缓存 + 显式安装 |
| 报错含 `npm ERR! code EINTEGRITY` | B2（本技能不适用，转停止条件 S2） |
| 依赖版本一致，报错随 `TZ`/runner 版本变化 | B3 环境差异（本技能不适用） |
| 同一 commit 重跑结果不稳定 | B4 flake（本技能不适用） |

**B1 清缓存 + 显式安装**
1. 在 `actions/cache` 步骤之后、`npm test` 之前插一步 `npm ls @acme/pricing`（换成被怀疑的包）
   - 期望：打印 `@acme/pricing@1.9.0`，与 lockfile 一致
   - 不匹配：打印旧版本（如 `@acme/pricing@1.8.3`）→ 确认走 B1；一致 → 转停止条件 S1
2. `grep -n -A3 "restore-keys" .github/workflows/ci.yml`
   - 期望：看到前缀兜底 `${{ runner.os }}-nm-`
   - 不匹配：没有 `restore-keys` 但版本仍不符 → 转停止条件 S2
3. 改 workflow：`path` 改为 `~/.npm`，删掉 `restore-keys`，在 `npm test` 前加 `- run: npm ci`
   - 期望：CI 日志里 `npm ls @acme/pricing` 打印 `1.9.0`，`npm test` 通过
   - 不匹配：仍打印旧版本 → 转停止条件 S2
4. 推两个只改测试文件的 commit
   - 期望：连续 CI 全绿
   - 不匹配：仍红 → 转停止条件 S3

**回滚**：`git revert <workflow-commit>` 或 `git checkout HEAD~1 -- .github/workflows/ci.yml` 后重推；缓存侧无需回滚，旧 key 由 GitHub 自行淘汰。

**停止条件**：
- S1：`npm ls` 版本与 lockfile 一致但测试仍失败 → 根因不是缓存污染，停止并按决策表转 B3/B4。
- S2：版本不符（或 `EINTEGRITY`）且删 `restore-keys` + `npm ci` 后仍不符 → 停止本技能，转 integrity/registry 方向排查（见 See also）。
- S3：两轮 workflow 改动后 CI 仍必挂 → 停止改 workflow，改为在 runner 上 dump 完整环境（`node -v`、`npm ls --all`、打印实际命中的 cache key）后再定位。

## Calibration

**逐条置信度**：
| 事实/结论 | 置信度 | 依据 |
|---|---|---|
| F1 | verified | CI 内 `npm ls` 打印 `@acme/pricing@1.8.3`，与本地 `1.9.0` 对照 |
| F2 | verified | workflow 节选里 `cache: 'npm'` 与缺失 `npm ci` 可直接读出 |
| F3 | verified | `grep` 命令输出含 `package.json:12` 与 `package-lock.json:141` |
| F4 | verified | CI 临时步骤输出 `@acme/pricing@1.9.0` 且随后 `npm test` 通过 |
| F5 | verified | 连续 6 个 commit CI 全绿 + 本地等价命令绿 |
| F6 | verified | 本地 20 次全绿 + 同 commit 重跑必挂 |
| F7 | verified | CI 日志含报错串与 `test/billing.spec.ts:42:20` |
| F8 | verified | `git diff` 确认只改字符串字面量 |
| “pnpm 有同样问题” | inferred | 机制类比，未实测 |
| “托管 runner 缓存淘汰（7 天/10 GB）会让问题自愈” | inferred | 未观察缓存生命周期 |
| “保留 `restore-keys` 但加 `npm ci` 也足够” | inferred | 直接删了前缀，没做这个对照 |
| “`EINTEGRITY` 那次根因是上游重发 `1.9.0`” | inferred | 来自另一次会话，本次未复核 |

**证伪条件**（出现即本技能失效或需重写）：
- `actions/cache` 改变 `restore-keys` 语义（前缀匹配改为精确匹配）→ F1 失效。
- `actions/setup-node` 的 `cache: 'npm'` 开始负责安装依赖 → F2 失效。
- 已改为只缓存 `~/.npm` + 显式 `npm ci` 后，仍出现 CI 依赖版本与 lockfile 不一致 → 机制链错误，整份技能重写。

**未知清单**：
- pnpm（`cache: 'pnpm'`）是否有同样问题：未验证。验证方法 = 在 pnpm 项目里复刻同样的 `restore-keys` 前缀缓存配置，CI 里打印 `pnpm ls <pkg>` 对比 lockfile。
- GitHub 托管 runner 缓存淘汰策略（7 天 / 10 GB）是否让问题自愈：未验证。验证方法 = 记录缓存 key 创建时间，观察超期后是否 miss。
- 保留 `restore-keys` 只加 `npm ci` 是否也足够：未验证。验证方法 = 开两个分支各跑 3 个只改测试的 commit 做 A/B。
- `npm ERR! code EINTEGRITY` 那次的根因与修法本次未复核。

**复审日期**：2027-05-10（到期重跑 Facts 的复核命令，跑不通的事实降级进未知清单）

**使用台账**：
| 日期 | 场景 | 结果 |
|---|---|---|
| 2026-11-10 | 首次抽取（会话 S3） | — |

## See also

- `npm ERR! code EINTEGRITY` / `integrity checksum failed when using sha512`：不同根因（上游重发同版本），修法是 `npm cache clean --force` + 锁定到未被重发的版本，或 `npm ci --prefer-online`；本技能对其无效。
- GitHub Actions 缓存文档：`https://docs.github.com/en/actions/using-workflows/caching-dependencies-to-speed-up-workflows`
- npm `npm ci` 文档：`https://docs.npmjs.com/cli/v10/commands/npm-ci`
