---
name: claude-code-custom-skill-development
description: |
  在Claude Code中开发自定义skill的完整指南。包括项目结构、配置方法、定时任务集成、MCP工具调用等。
  适用于需要创建自动化工作流、定期任务、工具集成等场景。
author: Claude Code
version: 1.0.0
date: 2026-04-22
---

# Claude Code自定义技能开发指南

## Problem
Claude Code的技能系统非常强大，但缺乏系统的开发指南，开发者在创建自定义技能时经常遇到：
- 不知道正确的项目结构和配置格式
- 不清楚如何集成MCP工具和其他内置功能
- 不知道如何设置定时任务自动执行技能
- 不知道如何让技能在全局和项目级别都能使用

## Context / Trigger Conditions
- 需要创建自动化工作流定期执行任务
- 需要集成外部API（如飞书webhook、Notion MCP等）
- 需要将重复使用的工作流封装为可复用的技能
- 看到`/[skill-name]`这种命令格式想知道如何创建

## Solution
### 1. 技能结构
每个技能放在独立的目录中，结构如下：
```
skill-name/
├── SKILL.md          # 技能定义文件（必填）
├── run.sh            # 主执行脚本（可选，也可以是Python等其他语言）
├── scripts/          # 辅助脚本目录（可选）
└── assets/           # 资源文件目录（可选）
```

### 2. SKILL.md配置格式
```markdown
---
name: skill-name-in-kebab-case
description: |
  详细描述技能的用途、触发条件、解决的问题。要足够具体，方便语义匹配。
  例如："每日从Notion数据库随机选择研究者，总结后发送到飞书webhook"
author: 作者名
version: 1.0.0
date: YYYY-MM-DD
---

# 技能名称
## Problem
解决的问题描述

## Context / Trigger Conditions
使用场景和触发条件

## Solution
使用方法和实现逻辑

## Verification
验证方式

## Example
示例

## Notes
注意事项
```

### 3. 技能安装位置
- **项目级技能**：放在项目根目录的`.claude/skills/`下，只在当前项目可用
- **全局技能**：放在`~/.claude/skills/`下，所有项目都可以使用

### 4. 定时任务集成
使用Claude Code内置的Cron工具设置定期执行：
```bash
# 添加定时任务，每天上午9点执行
/cron add "0 9 * * *" "/skill-command"

# 查看所有定时任务
/cron list

# 删除定时任务
/cron delete <job-id>
```

### 5. MCP工具调用
在技能中可以直接使用已配置的MCP工具，例如Notion：
```python
# 在Python中调用MCP Notion工具
import subprocess
import json

def fetch_notion_page(page_id):
    result = subprocess.run([
        "mcp", "notion", "fetch", 
        "--id", page_id
    ], capture_output=True, text=True)
    return json.loads(result.stdout)
```

### 6. 外部API集成
直接使用curl或HTTP客户端调用外部API，例如飞书webhook：
```bash
# 发送飞书消息
curl -X POST \
  -H "Content-Type: application/json" \
  -d "$MESSAGE_BODY" \
  "$FEISHU_WEBHOOK_URL"
```

## Verification
1. 技能创建后，在Claude Code中输入`/[skill-name]`可以触发执行
2. 定时任务到时间会自动执行，并且可以在`/cron list`中看到
3. 外部API调用返回正确的响应结果

## Example
### 每日推送技能实现
1. 创建技能目录：`.claude/skills/daily-cs-spotlight/`
2. 编写SKILL.md定义文件
3. 编写run.sh执行脚本：
   - 从Notion MCP获取数据
   - LLM总结内容
   - 格式化为飞书富文本
   - 调用webhook发送
4. 设置定时任务：`/cron add "0 9 * * *" "/daily-cs-spotlight"`

## Notes
- 技能描述要尽可能具体，包含触发条件和使用场景，方便语义匹配
- 敏感信息（如webhook URL、API密钥）使用环境变量传递，不要硬编码
- 定时任务默认是会话级别的，重启Claude Code后会失效，如需永久保存需要添加`durable: true`参数
- 技能脚本可以使用任何语言，只要系统中安装了对应的解释器
- 可以通过Makefile提供便捷的操作命令，如`make notify`、`make setup-cron`等

## References
- [Claude Code Skills Documentation](https://docs.anthropic.com/claude-code/skills)
- [Model Context Protocol (MCP) Documentation](https://modelcontextprotocol.io/)
- [飞书开放平台 - 自定义机器人文档](https://open.feishu.cn/documentation/client/custom-bot/overview)
