#!/bin/bash
# Claude Code 任务完成后发送飞书提醒
# 此脚本在 Claude Code TaskCompleted 事件时被调用

TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

# 收集项目信息
PROJECT_DIR=$(pwd)
PROJECT_NAME=$(basename "$PROJECT_DIR")

# Git 信息
GIT_BRANCH=""
GIT_REPO=""
GIT_LAST_COMMIT=""
if git rev-parse --is-inside-work-tree &>/dev/null; then
    GIT_BRANCH=$(git branch --show-current 2>/dev/null)
    GIT_REPO=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null)
    GIT_LAST_COMMIT=$(git log -1 --format="%s" 2>/dev/null | head -c 60)
fi

# 主机名
HOSTNAME=$(hostname 2>/dev/null || echo "unknown")

# 构建 lark_md 格式的描述
DESP="**项目**: ${GIT_REPO:-$PROJECT_NAME}"
DESP="${DESP}\n**目录**: ${PROJECT_DIR}"

if [ -n "$GIT_BRANCH" ]; then
    DESP="${DESP}\n**分支**: ${GIT_BRANCH}"
fi

if [ -n "$GIT_LAST_COMMIT" ]; then
    DESP="${DESP}\n**最近提交**: ${GIT_LAST_COMMIT}"
fi

DESP="${DESP}\n**用户**: $(whoami)@${HOSTNAME}"
DESP="${DESP}\n**完成时间**: ${TIMESTAMP}"

# 调用 wechat-reminder 发送提醒（使用飞书卡片格式）
LOG_FILE="$HOME/.claude/logs/claude-end.log"
mkdir -p "$(dirname "$LOG_FILE")"
RESULT=$($HOME/.local/bin/wechat-reminder --title "Claude Code 任务完成" --desp "$DESP" --color green 2>&1)
EXIT_CODE=$?
echo "[$TIMESTAMP] dir=$PROJECT_DIR exit=$EXIT_CODE FEISHU_URL_SET=${FEISHU_WEBHOOK_URL:+yes} result=$RESULT" >> "$LOG_FILE"
