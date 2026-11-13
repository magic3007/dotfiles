# 会话记录（节选）— 2026-11-12，仓库 ~/billing-api

**用户**：CI 上 `tests/test_invoice.py::test_due_date_label` 一会红一会绿，本地一直绿。查一下。

**Agent**：本地跑 20 次全绿：

```
$ pytest tests/test_invoice.py::test_due_date_label --count 20
20 passed in 3.41s
```

CI 日志里失败断言是：

```
AssertionError: assert '2026-03-02' == '2026-03-01'
 - 2026-03-01
 + 2026-03-02
```

**Agent**：先怀疑是数据库里 fixture 的时间戳不稳定，加了 `freezegun` 冻结 `datetime.now()`，CI 仍然偶发红。

**Agent**：再怀疑是测试间状态污染，加了 `--random-order` 本地复现，没复现。

**Agent**：对比 CI 与本地环境变量，发现 CI runner 的 `TZ` 未设置（UTC），本机 `TZ=Asia/Shanghai`。被测代码里：

```python
return invoice.due_at.astimezone().strftime("%Y-%m-%d")
```

`astimezone()` 不带参数时用**进程本地时区**。UTC 下 `due_at=2026-03-01T17:30Z` 渲染成 `2026-03-01`，东八区下渲染成 `2026-03-02`。CI 只在 UTC 日界附近的 fixture 上翻车，所以表现为偶发。

**Agent**：改成 `due_at.astimezone(ZoneInfo(settings.display_tz)).strftime(...)`，并在测试里显式传 `display_tz="Asia/Shanghai"`。CI 连续 30 次绿：

```
$ gh run list --workflow ci.yml --limit 30 --json conclusion -q '.[].conclusion' | sort | uniq -c
  30 success
```

总共排查了约 40 分钟。

**用户**：行。但你写的总结先讲了"我先怀疑 A，又怀疑 B"，结论在最后一段才出现。以后报告先给结论再给过程。

**Agent**：明白。
