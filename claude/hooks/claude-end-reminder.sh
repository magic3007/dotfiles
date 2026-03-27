#!/bin/bash
# Claude Code 运行结束后发送微信提醒
# 此脚本在 Claude Code 会话结束时被调用

# 获取当前时间戳
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

# 设置标题和描述
TITLE="Claude Code 会话结束"
DESP="Claude Code 运行于 $TIMESTAMP 结束。\n\n当前目录: $(pwd)\n用户: $(whoami)"

# 调用 wechat-reminder 发送提醒
$HOME/.local/bin/wechat-reminder --title "$TITLE" --desp "$DESP"

# 记录日志（可选）
LOG_FILE="$HOME/.claude/logs/claude-end.log"
mkdir -p "$(dirname "$LOG_FILE")"
echo "[$TIMESTAMP] Claude Code session ended, reminder sent." >> "$LOG_FILE"
