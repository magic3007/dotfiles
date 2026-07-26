# 每日自省 (Daily Self-Reflection)

每晚 22:07 自动生成自省报告并推送。

## 工作机制

1. **扫描 memory** — 查找今天修改的 `~/.claude/projects/*/memory/*.md` 文件
2. **运行 `/insights`** — 生成 Claude Code 使用分析报告（会话模式、摩擦点）
3. **生成报告** — 通过 DeepSeek API 分析数据，输出结构化自省报告
4. **推送通知** — 通过 wechat-reminder 发送到飞书/微信

## 报告内容

- 📋 **今日活动摘要** — 基于 memory 的今日工作要点
- 🔍 **Insights 发现** — 使用模式、效率问题、摩擦点
- 💡 **改进建议** — 最多 3 条可操作建议

## 安装

```bash
cd ~/dotfiles/self-reflection
./install.sh
```

## 管理

```bash
./install.sh              # 安装 cron 任务
./install.sh --status     # 查看安装状态
./install.sh --uninstall  # 卸载 cron 任务
```

## 手动执行

```bash
./daily-insights.sh
```

## 日志

```bash
tail -f ~/.claude/logs/daily-insights.log
```

## 依赖

- `claude` CLI（通过 nvm 安装）
- `wechat-reminder`（`~/.local/bin/wechat-reminder`）
- `DEEPSEEK_API_KEY` 环境变量
- `FEISHU_WEBHOOK_URL` 环境变量（飞书通道）

## 跨平台

- **macOS**: crontab（需终端有「完全磁盘访问权限」）
- **Linux**: crontab
