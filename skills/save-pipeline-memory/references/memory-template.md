# Pipeline Memory 模板

核心理念：**最终能跑通的 pipeline 每一步必须是脚本调用，不允许裸命令。**
读者应该只看"✅ Pipeline"一节就能复现，不必趟坑。

> ⚠️ **脚本强制规则**：Pipeline 节里如果出现了裸命令（如 `vela submit --flag1 ...`），说明工作没做完——先去把命令封装成脚本，再回来写 Pipeline Memory。

## 什么算"脚本调用" vs "裸命令"

```bash
# ❌ 裸命令 — 不允许出现在 Pipeline 节
vela submit --model-id 204737 --snippet-id 7047 --data /path/to/data.jsonl
python -c "import json; ..."

# ✅ 脚本调用 — 这才是 Pipeline 节应该有的形式
bash scripts/submit_eval.sh --config exprs/v1/config.yaml
python scripts/process_data.py --input ./data.jsonl --output ./results/
```

文件命名：`YYYY-MM-DD_HHMM_<简短任务描述>.md`

---

```markdown
# <任务标题>

**日期时间**: YYYY-MM-DD HH:MM
**工作目录**: <cwd>
**状态**: 已跑通 / 部分跑通 / 未跑通
**标签**: #tag1 #tag2

## 会话概览
2-4 句话概括目标、最终是否跑通、产出（脚本/文档）在哪。

## ✅ 最终可跑通的 Pipeline（主角）

前置条件：
- <依赖、环境变量（用键名，不写明文值）、需要的数据文件>

步骤（每一步是脚本调用，不记录裸命令）：
```bash
# 步骤 1：<做什么>
python scripts/step1_xxx.py --input <path> --output <path>

# 步骤 2：<做什么>
bash scripts/step2_yyy.sh --config <path>
```

产出脚本：
- `scripts/step1_xxx.py` — <一句话说明>
- `scripts/step2_yyy.sh` — <一句话说明>

验证方式：
```bash
<验证命令>
```
预期结果：<成功时应看到什么>

## 💡 弯路与经验（配角）

- **试过**: <做了什么> — **结果**: <为什么没走通> — **教训**: <结论 + 如何指向最终方案>
- **坑**: <非显而易见的陷阱> — **根因**: <根本原因> — **规避**: <如何避免>

## 关键决策
- **决策**: <选了什么> — **原因**: <为什么> — **放弃**: <放弃了什么>

## 产出与指标
- **脚本**: <路径列表>
- **数据/模型**: <路径 + 关键指标>

## 下一步 / 未解决
- <还差什么、下一步做什么>

## 相关资源
- <文档链接、ticket、参考文件>
```

## 填写要点

- **脚本化（硬约束，不可跳过）**：Pipeline 每一步写成 `bash scripts/xxx.sh --arg val` 或 `python scripts/xxx.py --arg val` 形式。**裸命令是完成前的中间状态，不是最终产出。** 如果你发现自己在 Pipeline 节里写裸命令，停下来，先去写脚本。
- **可复现**：命令和路径要具体，别人拿到脚本+数据就能跑
- **主配分明**：成功路径进 Pipeline，失败尝试进弯路
- **诚实**：没跑通就标注"部分跑通"，缺口写进下一步
- **不泄密**：密钥/token 用 `KEY=<redacted>` 引用
- **环境无关**：不假定特定工具名，用通用描述
