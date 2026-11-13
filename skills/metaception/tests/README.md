# metaception 评测

五个场景，两臂对照：`with_skill`（当前技能）vs `old_skill`（对照）。

## 场景

| 文件 | 考察点 |
|---|---|
| `scenarios/S1-corrections.md` | 四次纠正（流编辑器改源码两次、漏跑对账、systemd 相对路径），全部可自动化 |
| `scenarios/S2-debug-and-taste.md` | 40 分钟时区 bug + 一条审美纠正（报告先给结论） |
| `scenarios/S3-trivial.md` | 错别字修正，应当拒绝抽取 |
| `scenarios/S4-attribution-trap.md` | 用户给的机制解释是错的（`sed -i` 不吞 CRLF，真凶是叠加的行尾 strip 正则） |
| `scenarios/S5-taste-and-type.md` | 类型化重构：枚举、零值、命名、分层 |

`evals.json` 是这些场景加断言的定义。说话场景里的仓库（`~/svc-gateway` 等）不存在，会话记录里粘贴的命令输出就是全部证据；S4 的事实基线见 `S4` 的 ground truth（实测：`sed -i` 与 `perl -pi` 保留 CR，叠加 `s/[[:space:]]*$//` 后 CR 被剥）。

## 跑一轮

```sh
# 1. 为每个 eval × 两臂各起一个 subagent，产出写进 <workspace>/iteration-N/<eval>/<arm>/run-1/outputs/
# 2. 逐 run 记录 timing.json（total_duration_seconds / total_tokens）
python3 tests/grade_runs.py <workspace>/iteration-N
python3 -m scripts.aggregate_benchmark <workspace>/iteration-N --skill-name metaception   # 在 skill-creator 目录下
python3 <skill-creator>/eval-viewer/generate_review.py <workspace>/iteration-N \
  --skill-name metaception --benchmark <workspace>/iteration-N/benchmark.json \
  --previous-workspace <workspace>/iteration-<N-1> --static <workspace>/review-iteration-N.html
```

`grade_runs.py` 全机器判定，不引入评审口味。workspace 放仓库外（`~/.cache/metaception-workspace`）。

## 已知判分口径

- `aggregate_benchmark.py` 只认 `<arm>/run-1/grading.json`，且 pass_rate 读 `grading.json` 的 `summary.pass_rate`；两处不匹配时它静默出 0。`grade_runs.py` 已按它期望的结构写。
- 它按目录名排序取前两个 config 算 delta，`old_skill` 排在 `with_skill` 前面会导致 delta 符号反向；跑完要手工把 `run_summary` 的键顺序改成 `with_skill` 在前。
- `S3` 两臂都拒绝抽取，不区分；保留作过度抽取的护栏，不进识别力统计。
