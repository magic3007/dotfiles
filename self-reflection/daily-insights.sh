#!/bin/zsh
# 每日自省报告生成脚本
# 每晚 10:00 由 cron 调用，也可手动执行
#
# 流程:
#   1. 查找今天修改的 memory/*.md 文件
#   2. 调用 claude (DeepSeek API) 读取 memory + 运行 /insights
#   3. 创建飞书文档存放完整报告
#   4. 通过 lark-cli IM 发送文档链接提醒
#
# 依赖:
#   - claude CLI (通过 nvm)
#   - lark-cli (需完成 auth login，默认 --as user)
#   - DEEPSEEK_API_KEY 环境变量
#   - SELF_REFLECTION_LARK_CHAT_ID 环境变量（飞书群 ID 或个人 open_id，用于发送提醒）

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
command -v lark-cli >/dev/null 2>&1 || { log "错误: lark-cli 未找到"; exit 1; }

# 检查 lark-cli 认证状态
LARK_AUTH=$(LARKSUITE_CLI_NO_UPDATE_NOTIFIER=1 LARKSUITE_CLI_NO_SKILLS_NOTIFIER=1 lark-cli auth status --json --verify 2>&1)
if ! echo "$LARK_AUTH" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get('verified') else 1)" 2>/dev/null; then
    log "错误: lark-cli 未认证，请先运行 lark-cli auth login"
    exit 1
fi

# 检查 API key
if [[ -z "${DEEPSEEK_API_KEY:-}" ]]; then
    log "错误: DEEPSEEK_API_KEY 环境变量未设置"
    exit 1
fi

# 目标会话 ID（用于发送文档链接提醒）
LARK_CHAT_ID="${SELF_REFLECTION_LARK_CHAT_ID:-}"

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
REPORT_FILE=""
trap 'rm -f "$PROMPT_FILE" ${REPORT_FILE:+"$REPORT_FILE"}' EXIT

# Prompt 主体
cat > "$PROMPT_FILE" << 'ENDOFPROMPT'
你是一个每日自省助手。**所有输出必须使用中文。** 请严格按以下步骤操作：

## 步骤1: 读取今天的 memory 文件

ENDOFPROMPT

if [[ -n "$MEMORY_FILES" ]]; then
    echo "请使用 Read 工具逐个读取以下文件并用中文总结今日活动：" >> "$PROMPT_FILE"
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
**注意：/insights 生成的 HTML 是英文的，你需要把其中的核心信息翻译成中文后输出。**

## 步骤3: 输出每日自省报告

综合 memory 文件内容（如有）和 insights 报告，用**纯中文**输出一份结构化每日自省报告。

注意：这份报告将直接写入飞书文档，使用标准 Markdown 格式。

### 输出格式要求

严格按照以下结构输出，使用 Markdown 语法，**全文中文**：

# 📋 今日活动摘要
（根据 memory 文件总结今日做了什么，3-5 个要点。无文件则写"今日无记录"）

# 📊 Insights 报告
（/insights HTML 中的完整信息翻译为中文后输出，保留原文结构不要删减。如无数据则写"今日无 insights 数据"）

# 🔍 Insights 分析
（基于数据，用中文列出核心发现、使用模式、摩擦点、效率问题）

# 💡 改进建议
（最多 3 条具体可操作建议，中文）

### 语言要求
- **整个报告正文必须是中文**，包括标题、要点、分析、建议
- Insights 中的英文术语（如 model、token、skill 等）保留英文原文，但在括号中给出中文说明
- 日期、数据指标等数值原样保留，不翻译
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

# ---- 步骤 4: 创建飞书文档 ----
log "创建飞书文档..."

# 将报告写入临时文件（用 @file 传参避免 shell 转义问题）
REPORT_FILE=$(mktemp ./daily-insights-report-XXXXXX.md)
echo "$REPORT" > "$REPORT_FILE"

DOC_DATE=$(date '+%Y-%m-%d')
DOC_TITLE="📋 ${DOC_DATE} 每日自省报告"

# 创建飞书文档（Markdown 格式）
CREATE_RESULT=$(
    LARKSUITE_CLI_NO_UPDATE_NOTIFIER=1 LARKSUITE_CLI_NO_SKILLS_NOTIFIER=1 \
    lark-cli docs +create \
        --doc-format markdown \
        --title "$DOC_TITLE" \
        --content "@$REPORT_FILE" \
        --as user \
        --json 2>&1
)
CREATE_EXIT=$?
rm -f "$REPORT_FILE"

if [[ $CREATE_EXIT -ne 0 ]]; then
    log "错误: 飞书文档创建失败 (exit=$CREATE_EXIT)"
    log "输出: $(echo "$CREATE_RESULT" | head -10)"
    exit 1
fi

# 检查创建是否成功
if ! echo "$CREATE_RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get('ok') else 1)" 2>/dev/null; then
    log "错误: 飞书文档创建失败"
    log "$CREATE_RESULT"
    exit 1
fi

# 提取文档 URL
DOC_URL=$(echo "$CREATE_RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['document']['url'])" 2>/dev/null || echo "")
log "文档已创建: $DOC_URL"

# ---- 步骤 5: 发送 IM 提醒 ----
if [[ -n "$LARK_CHAT_ID" ]]; then
    log "发送文档链接提醒到 $LARK_CHAT_ID..."

    if [[ "$LARK_CHAT_ID" == oc_* ]]; then
        # 群聊
        LARKSUITE_CLI_NO_UPDATE_NOTIFIER=1 LARKSUITE_CLI_NO_SKILLS_NOTIFIER=1 \
        lark-cli im +messages-send \
            --chat-id "$LARK_CHAT_ID" \
            --markdown "📋 [每日自省报告 ${DOC_DATE}](${DOC_URL}) 已生成，点击查看。" \
            --as user 2>&1 | tee -a "$LOG_FILE" || true
    else
        # 个人（open_id，如 ou_xxx）
        LARKSUITE_CLI_NO_UPDATE_NOTIFIER=1 LARKSUITE_CLI_NO_SKILLS_NOTIFIER=1 \
        lark-cli im +messages-send \
            --user-id "$LARK_CHAT_ID" \
            --markdown "📋 [每日自省报告 ${DOC_DATE}](${DOC_URL}) 已生成，点击查看。" \
            --as user 2>&1 | tee -a "$LOG_FILE" || true
    fi
else
    log "未设置 SELF_REFLECTION_LARK_CHAT_ID，跳过 IM 提醒"
    log "在 ~/.zshenv 或 cron 环境中设置:"
    log "  export SELF_REFLECTION_LARK_CHAT_ID=ou_xxx   # 发给自己"
    log "  export SELF_REFLECTION_LARK_CHAT_ID=oc_xxx   # 发到群里"
fi

# 输出文档链接到 stdout
echo ""
echo "======================================"
echo "  自省报告已生成"
echo "  文档: $DOC_URL"
echo "======================================"

log "======== 自省报告流程完成 ========"
