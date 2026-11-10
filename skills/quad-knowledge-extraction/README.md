# Quad Knowledge Extraction

`claudeception` 的增强版：把"抽取会话知识"这件事，从自由格式 Markdown 升级为**按认知心理学四类知识分层的受校验结构**。

技能名 `quad-knowledge-extraction`；原技能 `claudeception` 保持原样，不做任何改动。

## 为什么

认知心理学把知识分为事实性、概念性、程序性、元认知四类。原版 claudeception 产出的技能文件里，
四类知识混在一起，导致四个可观测的失败模式：

| 缺失的知识类型 | 可观测后果 |
|---|---|
| 事实性 | 报错串被改写 → 检索永不命中；结论无法判断是否过期 |
| 概念性 | 只有"症状→补丁"，近似案例误用 |
| 程序性 | 步骤无分支/无回滚/无停止条件，换环境即失效 |
| 元认知 | 推测与实测混同，被当事实传播；技能永不失效 |

本技能给四类知识各自固定落位（`Facts` / `Model` / `Procedure` / `Calibration`），
并用 `scripts/validate_skill.py` 做机器校验。

## 文件

- `SKILL.md` — 技能本体：四类知识契约 + 七步抽取流程 + 四维质量门
- `resources/skill-template.md` — 抽取产出的模板
- `scripts/validate_skill.py` — 四维结构校验器（退出码 0=通过，1=有 FAIL，2=结构问题）
- `examples/esm-circular-import-tdz/SKILL.md` — 四维齐备的最小完整样例

## 用法

```
/quad-knowledge-extraction     # 会话回顾，抽取候选技能
python3 scripts/validate_skill.py <skill-dir>   # 校验产出
```

## 对照组

`skills/claudeception-classic/` 是原版 claudeception v3.1.0 的逐字副本（仅改 frontmatter `name`
以避免与 `claudeception` 重名冲突），作为 A/B 测试的对照臂。
