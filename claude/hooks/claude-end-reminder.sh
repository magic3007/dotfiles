#!/bin/bash
# Claude Code 任务完成后发送飞书提醒
# 此脚本在 Claude Code Stop/StopFailure/TaskCompleted 事件时被调用

# 读取 stdin JSON 输入（包含 hook 事件数据）
INPUT=$(cat)

TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

# 从 stdin 提取 Claude 的最后回复
LAST_REPLY=""
if [ -n "$INPUT" ]; then
    if command -v jq &>/dev/null; then
        LAST_REPLY=$(echo "$INPUT" | jq -r '.last_assistant_message // empty' 2>/dev/null)
    else
        LAST_REPLY=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('last_assistant_message',''))" 2>/dev/null)
    fi
fi

# 从 stdin 提取 Session ID
SESSION_ID=""
if [ -n "$INPUT" ]; then
    if command -v jq &>/dev/null; then
        SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
    else
        SESSION_ID=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('session_id',''))" 2>/dev/null)
    fi
fi

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

# 构建 lark_md 格式的描述（使用真实换行符而非字面 \n）
DESP="**项目**: ${GIT_REPO:-$PROJECT_NAME}"
DESP+=$'\n'"**目录**: ${PROJECT_DIR}"

if [ -n "$GIT_BRANCH" ]; then
    DESP+=$'\n'"**分支**: ${GIT_BRANCH}"
fi

if [ -n "$GIT_LAST_COMMIT" ]; then
    DESP+=$'\n'"**最近提交**: ${GIT_LAST_COMMIT}"
fi

if [ -n "$SESSION_ID" ]; then
    DESP+=$'\n'"**Session**: ${SESSION_ID}"
fi

DESP+=$'\n'"**用户**: $(whoami)@${HOSTNAME}"
DESP+=$'\n'"**完成时间**: ${TIMESTAMP}"

# 添加 Claude 的最后回复（完整内容，不截断）
if [ -n "$LAST_REPLY" ]; then
    DESP+=$'\n\n'"---"
    DESP+=$'\n'"**Claude 回复**:"
    DESP+=$'\n'"${LAST_REPLY}"
fi

# 调用 wechat-reminder 发送提醒（使用飞书卡片格式）
LOG_FILE="$HOME/.claude/logs/claude-end.log"
mkdir -p "$(dirname "$LOG_FILE")"
RESULT=$($HOME/.local/bin/wechat-reminder --title "Claude Code 任务完成" --desp "$DESP" --color green 2>&1)
EXIT_CODE=$?
echo "[$TIMESTAMP] dir=$PROJECT_DIR exit=$EXIT_CODE FEISHU_URL_SET=${FEISHU_WEBHOOK_URL:+yes} result=$RESULT" >> "$LOG_FILE"
