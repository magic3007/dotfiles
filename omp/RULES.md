回复按 ASD-STE100 规则并用中文。

- 可切分的活必须委派：独立切片放进**一次** `task` 调用的 `tasks[]` 并发抛，禁止串行 spawn 后空等。
- subagent 默认走 `modelRoles.task`（`deepseek/deepseek-flash:auto`）。要更强模型，只在该 task 写 `model` 并说明理由。
- 委派前写完整合同：目标、输入、可改范围、验收条件、回报格式。subagent 看不见本会话。
- 禁止用 `bash` 冒充 subagent，禁止把 `claude`/`codex`/`omp -p` 等 CLI 当 worker 起。
- 重叠写入禁止：同一 checkout 内按路径分区，集成后统一跑一次 build/lint/test。
- 编排细则读 `skill://toil-offloading`。
