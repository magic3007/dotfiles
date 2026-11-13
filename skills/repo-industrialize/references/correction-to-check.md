# 纠正 → 确定性检查

一条纠正只有在"能让流水线变红"之后才算处理完。只写进文档的约定会被下一个人、下一个 agent、下一个赶时间的自己绕过，而且绕过时没有任何信号。

## 第一步：把纠正写成可判定的一句话

可判定 = 给定仓库状态，能机械回答是或否。

| 原始纠正 | 不可判定写法 | 可判定写法 |
| --- | --- | --- |
| "别在代码里写注释" | 代码要干净 | `src/` 下的 `.py` 不得出现行内 `#` 注释（docstring 除外） |
| "不要再用 print 调试" | 注意日志规范 | `src/` 下不得出现 `print(`，日志走 `logging` |
| "配置不要硬编码路径" | 配置要集中 | 代码中不得出现 `/home/` 或 `C:\\` 字面量 |
| "改完要跑测试" | 要重视测试 | CI 必须执行 `pytest -q` 且退出码为 0 |
| "文档老是和代码对不上" | 文档要及时更新 | 文档中引用的仓库内路径必须存在 |

写不出可判定版本时，说明纠正本身还没想清楚，先把它想清楚，再谈自动化。

## 第二步：选强制手段

| 纠正类型 | 手段 | 典型实现 |
| --- | --- | --- |
| 禁止出现某种写法 | `script` | 自写扫描脚本，输出 `path:line`，有违规即非零退出 |
| 已有 linter 能表达的规则 | `lint` | 打开/新增规则（ruff、eslint、clippy、golangci-lint），CI 跑 lint |
| 曾经出过的行为错误 | `test` | 回归测试，先确认它在旧代码上失败 |
| 模块依赖方向、分层边界 | `script` | AST/import 扫描，或 import-linter 一类工具 |
| 生成物与源不同步 | `ci` | 重新生成后 `git diff --exit-code` |
| 格式、空白、行尾 | `lint` | formatter `--check` 模式 |
| 提交粒度、提交信息 | `ci` | 对 `git log` 范围做校验的脚本 |
| 配置或数据结构约束 | `test` | schema 校验测试 |

选择顺序：已有工具能表达就用工具（维护成本最低），其次写小脚本，最后才考虑降级。

## 第三步：写检查（契约）

检查脚本必须满足：

- **退出码即结论**：0 通过，非 0 失败。不要靠 stdout 文字判断。
- **可定位**：失败时逐行打印 `path:line: 说明`，让人不看脚本就知道改哪。
- **只读**：不修改仓库；需要自动修复时另做一个 `--fix` 入口，默认不开。
- **确定性**：不依赖网络、时钟、环境变量、文件遍历顺序。
- **快**：全仓库扫描控制在几秒内，否则没人会在本地跑。
- **可指定范围**：接受路径参数，这样同一个脚本既能扫真实代码，也能扫违规样本。

骨架见 [../assets/templates/check_example.py](../assets/templates/check_example.py)。

## 第四步：用违规样本证明它会失败

一个从不失败的检查和没有检查等价，而且更危险——它提供虚假的安全感。所以每条 enforced 纠正都要有反向证据：

- 首选 `prove` 命令：在 `.repo-std/checks/fixtures/<name>/` 放一份**最小**违规样本，`prove` 就是"拿同一个脚本扫这个目录"，预期非零退出。fixture 目录要排除在正常检查范围之外，否则真实扫描会一直红。
- 回归测试这类无法用 fixture 表达的，填 `prove_evidence`：记录你确实观察过它在修复前失败（红 → 绿）。这比没有强，但比 fixture 弱，能用 fixture 就别用它。

`corrections.py prove` 会把"在违规样本上退出 0"判为失败，这正是用来抓"写了个永远绿的检查"。

## 第五步：登记与接线

```bash
python <skill-dir>/scripts/corrections.py --ledger .repo-std/corrections.yml add \
  --origin "2026-11-10 对话：用户指出 src 下不该有行内注释" \
  --rule "src/ 下不得出现行内注释" \
  --kind script \
  --run   "python3 .repo-std/checks/no_inline_comments.py src" \
  --prove "python3 .repo-std/checks/no_inline_comments.py .repo-std/checks/fixtures/no_inline_comments"
```

`origin` 必须能追溯到纠正来源（日期 + 场景），这样后来者知道这条规则为什么存在，才敢在它过时时删掉它。

CI 接线（任意流水线等价）：

```yaml
- run: python .repo-std/../scripts/corrections.py --ledger .repo-std/corrections.yml verify
- run: python .repo-std/../scripts/corrections.py --ledger .repo-std/corrections.yml run
- run: python .repo-std/../scripts/corrections.py --ledger .repo-std/corrections.yml prove
```

脚本随 skill 分发时，在目标仓库里固定一个入口（例如 `make check` 或 `.repo-std/gate.sh`），CI 只调这个入口，避免每条流水线各写各的路径。

## 降级阶梯：当精确检查做不到

按顺序往下退，每退一级都要写明退的理由：

1. **精确检查**：零假阳、零假阴。
2. **近似检查，宁可漏不可误**：只抓高置信度模式（允许假阴，禁止假阳）。假阳会让人加豁免注释，最终整条规则被架空。
3. **抽样或统计闸门**：例如"文档悬挂引用数不得增加"，用基线数字卡住回潮，不要求一次清零。
4. **人工关卡但有强制位**：PR 模板必填项、CODEOWNERS 强制评审——仍然是机器拦人，不是文档劝人。
5. **`waived`**：填 `reason`（为什么机器判不了）、`surfaced_in`（它会在哪被重新看到）、`revisit`（具体日期）。复查日期一过，`verify` 就失败，逼你重新裁决。

禁止的处理方式只有一种：在某个 `.md` 里加一行"请注意……"，然后结案。
