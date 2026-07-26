#!/bin/zsh
# 每日自省报告生成脚本
# 每晚 10:00 由 cron 调用，也可手动执行
#
# 流程:
#   1. 查找今天修改的 memory/*.md 文件
#   2. 调用 claude (DeepSeek API) 读取 memory + 运行 /insights
#   3. 通过 wechat-reminder 发送结构化自省报告
#
# 依赖:
#   - claude CLI (通过 nvm)
#   - wechat-reminder (~/.local/bin/wechat-reminder)
#   - DEEPSEEK_API_KEY 环境变量
#   - FEISHU_WEBHOOK_URL 环境变量（可选，用于飞书通道）

set -euo pipefail

# ---- 日志设置 ----
LOG_DIR="$HOME/.claude/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/daily-insights.log"

log() {
    local ts
    ts=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$ts] $1" | tee -a "$LOG_FILE"
}

# ---- 环境准备 ----
# cron 环境下 PATH 最小，需要显式补充
# 尝试多种 nvm 路径以覆盖不同安装位置
for nvm_dir in "$HOME/.nvm" "/usr/local/nvm"; do
    if [[ -s "$nvm_dir/nvm.sh" ]]; then
        export NVM_DIR="$nvm_dir"
        break
    fi
done

# 在没有 nvm 的情况下，手动查找 node 安装
if [[ -z "${NVM_DIR:-}" ]]; then
    NODE_BIN=$(dirname "$(which node 2>/dev/null)" 2>/dev/null || true)
    if [[ -z "$NODE_BIN" ]]; then
        NODE_BIN="$HOME/.nvm/versions/node/$(ls "$HOME/.nvm/versions/node/" 2>/dev/null | sort -V | tail -1 || echo '')/bin"
    fi
else
    NODE_BIN="$NVM_DIR/versions/node/$(ls "$NVM_DIR/versions/node/" 2>/dev/null | sort -V | tail -1 || echo '')/bin"
fi

export PATH="$NODE_BIN:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

# 检查必需的工具
command -v claude >/dev/null 2>&1 || { log "错误: claude CLI 未找到（PATH=$PATH）"; exit 1; }
command -v wechat-reminder >/dev/null 2>&1 || { log "错误: wechat-reminder 未找到"; exit 1; }

# 检查 API key
if [[ -z "${DEEPSEEK_API_KEY:-}" ]]; then
    log "错误: DEEPSEEK_API_KEY 环境变量未设置"
    exit 1
fi

log "======== 开始每日自省 ========"

# ---- 步骤 1: 查找今天修改的 memory 文件 ----
# 创建今天午夜的参考文件（跨平台）
MIDNIGHT_REF="/tmp/daily-insights-midnight.$$"

if [[ "$(uname)" == "Darwin" ]]; then
    # macOS BSD date
    touch -t "$(date -v0H -v0M -v0S '+%Y%m%d%H%M.%S')" "$MIDNIGHT_REF"
else
    # Linux GNU date
    touch -d "today 00:00:00" "$MIDNIGHT_REF"
fi

MEMORY_FILES=""
if [[ -d "$HOME/.claude/projects" ]]; then
    MEMORY_FILES=$(find "$HOME/.claude/projects/" -path "*/memory/*.md" -newer "$MIDNIGHT_REF" 2>/dev/null || true)
fi
rm -f "$MIDNIGHT_REF"

if [[ -n "$MEMORY_FILES" ]]; then
    FILE_COUNT=$(echo "$MEMORY_FILES" | wc -l | tr -d ' ')
    log "找到 $FILE_COUNT 个今日 memory 文件"
else
    log "今日无 memory 文件"
fi

# ---- 步骤 2: 构建 prompt ----
# 使用临时文件放入 prompt 以避免 shell 转义问题
PROMPT_FILE=$(mktemp /tmp/daily-insights-prompt.XXXXXX)
trap "rm -f $PROMPT_FILE" EXIT

# Prompt 主体
cat > "$PROMPT_FILE" << 'ENDOFPROMPT'
你是一个每日自省助手。请严格按以下步骤操作：

## 步骤1: 读取今天的 memory 文件

ENDOFPROMPT

if [[ -n "$MEMORY_FILES" ]]; then
    echo "请使用 Read 工具逐个读取以下文件并总结今日活动：" >> "$PROMPT_FILE"
    echo "$MEMORY_FILES" | while IFS= read -r f; do
        echo "  - $f" >> "$PROMPT_FILE"
    done
else
    echo "今天没有 memory 文件，跳过此步骤。" >> "$PROMPT_FILE"
fi

cat >> "$PROMPT_FILE" << 'ENDOFPROMPT'

## 步骤2: 运行并读取 insights
先运行 `/insights` 命令生成 insights 报告（记住输出的文件路径）。
然后用 Read 工具读取该 HTML 报告的完整内容。

## 步骤3: 输出每日自省报告

综合 memory 文件内容（如有）和 insights 报告，输出一份结构化每日自省报告。

### 输出格式要求

使用飞书 lark_md 格式。注意：lark_md 不支持 Markdown 表格，不要使用表格。

严格按照以下四个部分输出：

📋 **今日活动摘要**
（根据 memory 文件总结今日做了什么，3-5 个要点，每点一行。无文件则写"今日无记录"）

📊 **Insights 报告**
（完整提取 /insights HTML 报告中的文本内容，保留原文，不要总结或删减。如果没有 insights 数据则写"今日无 insights 数据"）

🔍 **Insights 分析**
（基于 insights 报告的核心发现、使用模式、摩擦点、效率问题。每点一行，不超过 5 点）

💡 **改进建议**
（基于以上数据，给出最多 3 条具体可操作的改进建议。每条一行，不空洞）

### 风格要求
- 不要用代码块，不要用 Markdown 表格
- 直接输出报告正文，不要加任何前言或后记
- 在报告末尾加上一行：📎 完整报告: file://<报告文件路径>
- 完整保留原始报告的文字内容
ENDOFPROMPT

PROMPT=$(cat "$PROMPT_FILE")

# ---- 步骤 3: 调用 claude ----
log "开始调用 claude..."

# 使用与 _claude_with_api 相同的环境变量配置
REPORT=$(
    env -u ANTHROPIC_API_KEY \
        ANTHROPIC_BASE_URL="https://api.deepseek.com/anthropic" \
        ANTHROPIC_AUTH_TOKEN="${DEEPSEEK_API_KEY}" \
        API_TIMEOUT_MS=600000 \
        ANTHROPIC_MODEL="deepseek-v4-pro[1m]" \
        ANTHROPIC_DEFAULT_SONNET_MODEL="deepseek-v4-pro[1m]" \
        ANTHROPIC_DEFAULT_OPUS_MODEL="deepseek-v4-pro[1m]" \
        ANTHROPIC_DEFAULT_HAIKU_MODEL="deepseek-v4-pro[1m]" \
        ANTHROPIC_SMALL_FAST_MODEL="deepseek-v4-pro[1m]" \
        CLAUDE_CODE_SUBAGENT_MODEL="deepseek-v4-pro[1m]" \
        CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
        CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 \
        claude -p "$PROMPT" \
            --print \
            --output-format text \
            --dangerously-skip-permissions \
            --add-dir "$HOME/.claude/projects" \
            --add-dir "$HOME/.claude/usage-data" \
            2>&1
)
CLAUDE_EXIT=$?

if [[ $CLAUDE_EXIT -ne 0 ]]; then
    log "错误: claude 调用失败 (exit=$CLAUDE_EXIT)"
    log "claude 输出: $(echo "$REPORT" | head -20)"
    exit 1
fi

# 检查是否为空
if [[ -z "${REPORT// }" ]]; then
    log "错误: claude 返回空报告"
    exit 1
fi

log "claude 返回 ${#REPORT} 字符的报告"

# ---- 步骤 4: 发送通知 ----
log "发送自省报告..."

TITLE="📋 $(date '+%Y-%m-%d') 每日自省报告"
SEND_RESULT=$(wechat-reminder --title "$TITLE" --desp "$REPORT" --color wathet 2>&1)
SEND_EXIT=$?

echo "$SEND_RESULT" | tee -a "$LOG_FILE"

if [[ $SEND_EXIT -eq 0 ]]; then
    log "======== 自省报告发送成功 ========"
else
    log "======== 自省报告发送失败 ========"
    exit 1
fi
