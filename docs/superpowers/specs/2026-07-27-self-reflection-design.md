# Daily Self-Reflection 系统设计

> 2026-07-27 | dotfiles 项目

## 目标

每天晚上 22:07 自动生成个人自省报告，包含今日活动摘要、Claude Code 使用分析和可操作改进建议，通过飞书/微信推送到手机。

## 架构

```
cron (22:07 daily)
  └─ zsh -l daily-insights.sh
       ├─ find today's memory/*.md files (~/.claude/projects/*/memory/)
       ├─ claude -p (DeepSeek API) — 一次调用完成:
       │    ├─ Read memory files → 今日活动摘要
       │    ├─ Run /insights → 读取报告 HTML
       │    └─ Output 结构化自省报告 (lark_md)
       └─ wechat-reminder --desp <报告>
            ├─ 飞书 (FEISHU_WEBHOOK_URL)
            └─ 微信 (PUSHDEER_KEY)
```

## 关键决策

| 决策 | 选择 | 理由 |
|------|------|------|
| 定时机制 | 系统级 crontab | 不依赖 Claude Code 是否运行，最可靠 |
| Shell 引擎 | zsh | 用户主 shell，zenv/dotfiles 都配置在 zsh |
| API 后端 | DeepSeek V4 Pro | 用户主用 dsccpro，成本低 |
| 调用次数 | 一次 dsccpro | 上下文连贯，节省 API 调用 |
| 消息格式 | lark_md + wechat-reminder | 复用已有基础设施，飞书卡片 + 微信双通道 |
| 跨平台 | uname 判断 + find 参考文件法 | BSD/GNU 差异在少数几行内消化 |
| 安装器 | 独立 install.sh | 幂等，crontab 管理，不依赖 Dotbot |
| 错误处理 | 日志 + 非零退出 | 参考 claude-end-reminder.sh 模式 |

## 文件

```
self-reflection/
├── daily-insights.sh   # 主脚本 (cron 调用 / 手动执行)
├── install.sh          # crontab 安装/卸载/状态 (幂等)
└── README.md           # 使用说明
```

## Prompt 设计

一次 dsccpro 调用中包含三个步骤:
1. Read memory 文件 → 提取今日活动
2. `/insights` → 读取生成的 HTML 报告
3. 综合输出结构化的三栏报告 (活动摘要 / Insights / 改进建议)

输出格式约束: lark_md (不用表格)，每条 ≤50 字，手机端可读。

## 错误处理

- PATH 未准备好 → 自动发现 nvm/node 路径
- DEEPSEEK_API_KEY 未设置 → 退出 + 日志
- claude 调用失败 → 日志记录输出，不发送空消息
- wechat-reminder 失败 → 日志记录
- 无 memory 文件 → 降级：只做 insights + 改进建议

## 不做的

- 不依赖 Git (不分析 commit 历史)
- 不依赖 CLAUDE.md (不改动项目配置)
- 不需要 Dotbot 安装步骤
- 不使用 Claude Code CronCreate (需要 session 存活)
