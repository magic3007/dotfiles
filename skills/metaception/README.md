# Metaception

`claudeception` 的增强版。两条增量：

1. **纠正优先变成检查**：会话里每一条纠正，先走形态阶梯（`eliminate` → `type` → `test` → `lint` → `hook`/`ci` → `runtime-assert` → `command` → `prose`），取第一个可行级别产出**确定性检查**；只有确实无法自动化的，才写成散文，并记录为什么不能。
2. **知识分层 + 机器校验**：没能变成检查的部分，按认知心理学四类知识固定落位，再用 `scripts/validate_skill.py` 做结构校验。

技能名 `metaception`；前身 `claudeception` 保持原样，不做任何改动。

## 为什么

往规则文件里加一行散文，是成本最低、效果最差的纠正方式：它要求未来的 agent 恰好读到、恰好记住、恰好在正确时刻联想起来。三个"恰好"相乘，命中率很低，而且规则越长，每一行被注意到的概率越低——加规则本身会稀释已有规则。

确定性检查没有这个问题：固定时刻无条件执行，输出 0 或 1，不依赖注意力。

配套的硬约束是**负控**：写完检查必须把错误故意写回去，确认它真的失败。原因是常见失败模式为路径/glob/正则写错导致检查永远 PASS——这比没有检查更糟，它提供虚假安全感。

剩下的知识按四类分层，各自对应一个可观测的失败模式：

| 缺失的知识类型 | 可观测后果 |
|---|---|
| 事实性 | 报错串被改写 → 检索永不命中；结论无法判断是否过期 |
| 概念性 | 只有"症状→补丁"，近似案例误用 |
| 程序性 | 步骤无分支/无回滚/无停止条件，换环境即失效 |
| 元认知 | 推测与实测混同，被当事实传播；技能永不失效 |

落位固定为 `Facts` / `Model` / `Checks` / `Procedure` / `Calibration`。

## 文件

- `SKILL.md` — 技能本体：形态阶梯 + 四类知识契约 + 九步流程 + 质量门
- `resources/skill-template.md` — 抽取产出的模板
- `scripts/validate_skill.py` — 结构校验器（退出码 0=通过，1=有 FAIL，2=结构问题）
- `examples/esm-circular-import-tdz/SKILL.md` — 五块齐备的最小完整样例（校验 32/32）

## 校验器覆盖的门

| 维度 | 检查 |
|---|---|
| factual | `## Facts` 存在；6 列齐全；每行证据/复核命令/生效条件/日期非空且非空话 |
| conceptual | 机制链、分类树、判别标准、边界 |
| executable | `## Checks` 存在；6 列齐全；**每行有实测负控**（`MISSING`/`TODO` 判 FAIL）；形态取自受控词表；弱形态需降级理由；Model/Procedure 内无"记得/务必"类人肉提醒 |
| procedural | 决策表、每步期望输出、回滚、停止条件 |
| metacognitive | 逐条置信度（verified/inferred/assumed）、证伪条件、未知清单、绝对日期复审 |
| retrieval | description 存在、≥2 条编号触发、字面量与 Facts 对齐、≤800 字符 |
| hygiene | 无凭据/密钥、无内网地址 |

## 用法

```sh
/metaception                                     # 会话回顾：先列纠正清单，再判定可执行化
python3 scripts/validate_skill.py <skill-dir>    # 校验产出，退出码 0 才算完成
```

## 对照组

A/B 对照臂用 `skills/claudeception` 本体（upstream v3.1.0，未改动）。
