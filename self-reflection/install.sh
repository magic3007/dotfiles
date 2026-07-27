#!/bin/bash
# 安装每日自省 cron 任务
# 用法: ./install.sh          安装 cron 任务
#       ./install.sh --uninstall  卸载 cron 任务
#       ./install.sh --status     查看安装状态
#
# 跨平台: macOS (crontab + launchd 备选) / Linux (crontab)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/daily-insights.sh"
CRON_MARKER="# daily-self-reflection (managed by install.sh)"
CRON_ENTRY="7 22 * * * LARKSUITE_CLI_NO_UPDATE_NOTIFIER=1 LARKSUITE_CLI_NO_SKILLS_NOTIFIER=1 /bin/zsh -l '$SCRIPT_PATH' $CRON_MARKER"

# ---- 颜色 ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

msg_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
msg_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
msg_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ---- 检查 ----
check_prereqs() {
    local ok=true

    if [[ ! -f "$SCRIPT_PATH" ]]; then
        msg_error "脚本不存在: $SCRIPT_PATH"
        ok=false
    fi

    if [[ ! -x "$SCRIPT_PATH" ]]; then
        msg_error "脚本不可执行: $SCRIPT_PATH (运行 chmod +x $SCRIPT_PATH)"
        ok=false
    fi

    if ! command -v lark-cli &>/dev/null; then
        msg_warn "lark-cli 不可用，请先安装: lark-cli update"
    fi

    if ! command -v crontab &>/dev/null; then
        msg_error "crontab 不可用"
        ok=false
    fi

    if [[ "$ok" == false ]]; then
        exit 1
    fi
}

# ---- 状态查询 ----
show_status() {
    check_prereqs

    if crontab -l 2>/dev/null | grep -qF "$SCRIPT_PATH"; then
        msg_info "cron 任务已安装 ✓"
        echo ""
        crontab -l 2>/dev/null | grep -F "$SCRIPT_PATH"
    else
        msg_info "cron 任务未安装"
    fi
}

# ---- 安装 ----
install_cron() {
    check_prereqs

    # 检查是否已安装（幂等）
    if crontab -l 2>/dev/null | grep -qF "$SCRIPT_PATH"; then
        msg_info "cron 任务已存在，跳过安装"
        crontab -l 2>/dev/null | grep -F "$SCRIPT_PATH"
        echo ""
        msg_info "如需重新安装，请先运行 ./install.sh --uninstall"
        return 0
    fi

    # 添加 crontab 条目
    # 使用临时文件来处理 crontab，避免管道中的错误被掩盖
    local tmp_cron
    tmp_cron=$(mktemp /tmp/crontab.XXXXXX)
    crontab -l 2>/dev/null > "$tmp_cron" || true

    # 确保文件末尾有换行
    if [[ -s "$tmp_cron" ]]; then
        echo "" >> "$tmp_cron"
    fi

    echo "$CRON_ENTRY" >> "$tmp_cron"

    if crontab "$tmp_cron"; then
        msg_info "cron 任务安装成功 ✓"
        echo ""
        echo "  时间: 每晚 22:07 (UTC+8)"
        echo "  脚本: $SCRIPT_PATH"
        echo "  日志: ~/.claude/logs/daily-insights.log"
        echo ""
        crontab -l 2>/dev/null | grep -F "$SCRIPT_PATH"
    else
        msg_error "crontab 安装失败"
        rm -f "$tmp_cron"
        exit 1
    fi

    rm -f "$tmp_cron"

    # macOS 特别提示
    if [[ "$(uname)" == "Darwin" ]]; then
        echo ""
        msg_warn "macOS 用户: 如果 cron 不执行，请确保终端/iTerm2 有「完全磁盘访问权限」"
        msg_warn "系统设置 → 隐私与安全性 → 完全磁盘访问权限 → 添加终端"
        echo ""
        msg_warn "同时确认已设置环境变量（在 ~/.zshenv 中）:"
        msg_warn "  DEEPSEEK_API_KEY"
        msg_warn "  SELF_REFLECTION_LARK_CHAT_ID (可选)"
    fi
}

# ---- 卸载 ----
uninstall_cron() {
    check_prereqs

    if ! crontab -l 2>/dev/null | grep -qF "$SCRIPT_PATH"; then
        msg_info "cron 任务未安装，无需卸载"
        return 0
    fi

    # 移除匹配的条目
    local tmp_cron
    tmp_cron=$(mktemp /tmp/crontab.XXXXXX)
    crontab -l 2>/dev/null | grep -vF "$SCRIPT_PATH" > "$tmp_cron" || true

    # 移除尾部空行（跨平台兼容）
    if [[ -s "$tmp_cron" ]]; then
        if [[ "$(uname)" == "Darwin" ]]; then
            sed -i '' -e :a -e '/./,$!d;/^\n*$/{$d;N;};/\n$/ba' "$tmp_cron" 2>/dev/null || true
        else
            sed -i -e :a -e '/./,$!d;/^\n*$/{$d;N;};/\n$/ba' "$tmp_cron" 2>/dev/null || true
        fi
    fi

    if [[ -s "$tmp_cron" ]]; then
        crontab "$tmp_cron"
    else
        # 空 crontab → 删除
        crontab -r 2>/dev/null || true
    fi

    rm -f "$tmp_cron"
    msg_info "cron 任务已卸载 ✓"
}

# ---- 主入口 ----
main() {
    echo "=============================="
    echo "  每日自省 Cron 安装工具"
    echo "=============================="
    echo ""

    case "${1:-install}" in
        --status)
            show_status
            ;;
        --uninstall)
            uninstall_cron
            ;;
        install|--install)
            install_cron
            ;;
        *)
            echo "用法: $0 [install|--uninstall|--status]"
            echo ""
            echo "  install     安装 cron 任务（默认）"
            echo "  --uninstall 卸载 cron 任务"
            echo "  --status    查看安装状态"
            exit 1
            ;;
    esac
}

main "$@"
