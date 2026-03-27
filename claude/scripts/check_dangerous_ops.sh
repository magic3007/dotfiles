#!/bin/bash
# PreToolUse hook: 检测危险操作
# 安全目录（可自由删除/覆盖，无需确认）: output/, test_output/, debug_output/
# 注意：/tmp/ 不在安全目录，Claude 不应向 /tmp/ 写入

TOOL_INPUT="$CLAUDE_TOOL_INPUT"

SAFE_PATTERNS=(
    "^output/"
    "^test_output/"
    "^debug_output/"
    "^\./output/"
    "^\./test_output/"
    "^\./debug_output/"
)

is_safe_path() {
    local path="$1"
    for pattern in "${SAFE_PATTERNS[@]}"; do
        if echo "$path" | grep -qE "$pattern"; then
            return 0
        fi
    done
    return 1
}

warn_and_exit() {
    local category="$1"
    local detail="$2"
    local cmd="$3"
    echo "DANGEROUS: $category"
    echo "详情: $detail"
    [ -n "$cmd" ] && echo "命令: $cmd"
    echo ""
    echo "如需继续，请确认操作"
    exit 2
}

check_bash() {
    local input="$1"

    # === Git 危险操作 ===
    if echo "$input" | grep -qE "git\s+reset\s+--hard"; then
        warn_and_exit "Git 硬重置" "git reset --hard 会丢弃所有未提交的修改" "$input"
    fi
    if echo "$input" | grep -qE "git\s+checkout\s+(--\s+)?\."; then
        warn_and_exit "Git 丢弃修改" "git checkout . 会丢弃工作区所有修改" "$input"
    fi
    if echo "$input" | grep -qE "git\s+checkout\s+[^-]" && ! echo "$input" | grep -qE "git\s+checkout\s+-b"; then
        if echo "$input" | grep -qE "git\s+checkout\s+(HEAD|origin|main|master|\w+)\s+--?\s+\S+"; then
            warn_and_exit "Git 覆盖文件" "git checkout <ref> -- <file> 会覆盖未提交的文件修改" "$input"
        fi
    fi
    if echo "$input" | grep -qE "git\s+restore\s+(--staged\s+)?\."; then
        warn_and_exit "Git 恢复" "git restore 会丢弃工作区或暂存区的修改" "$input"
    fi
    if echo "$input" | grep -qE "git\s+clean\s+.*-f"; then
        warn_and_exit "Git 清理" "git clean -f 会删除未跟踪的文件" "$input"
    fi
    if echo "$input" | grep -qE "git\s+stash\s+(drop|clear)"; then
        warn_and_exit "Git Stash 删除" "git stash drop/clear 会永久删除暂存的修改" "$input"
    fi
    if echo "$input" | grep -qE "git\s+push\s+.*--force|git\s+push\s+-f"; then
        warn_and_exit "Git 强制推送" "git push --force 会覆盖远程仓库历史，可能影响他人" "$input"
    fi
    if echo "$input" | grep -qE "git\s+branch\s+-D"; then
        warn_and_exit "Git 强制删除分支" "git branch -D 会强制删除分支，可能丢失未合并的提交" "$input"
    fi
    if echo "$input" | grep -qE "git\s+rebase\s+" && ! echo "$input" | grep -qE "git\s+rebase\s+--abort"; then
        warn_and_exit "Git Rebase" "git rebase 会重写提交历史，确保已备份或了解后果" "$input"
    fi

    # === 文件删除 ===
    if echo "$input" | grep -qE "rm\s+(-[rRf]+\s+)*[^\s;|&-]"; then
        paths=$(echo "$input" | grep -oE "rm\s+(-[rRf]+\s+)*[^\s;|&]+" | sed 's/rm\s*-[rRf]*\s*//')
        for path in $paths; do
            [[ "$path" == -* ]] && continue
            if ! is_safe_path "$path"; then
                warn_and_exit "非安全目录删除" "路径: $path (安全目录: output/, test_output/, debug_output/)" "$input"
            fi
        done
    fi

    # === 写入 /tmp/ ===
    if echo "$input" | grep -qE ">\s*/tmp/|>>\s*/tmp/"; then
        warn_and_exit "写入 /tmp/" "请使用项目目录或 /data/minimax-dialogue/data/users/<user>/，而非 /tmp/" "$input"
    fi

    # === 覆盖重定向 ===
    if echo "$input" | grep -qE ">\s*/[^t]|>\s*[^/\s]"; then
        target=$(echo "$input" | grep -oE ">\s*[^\s;|&]+" | sed 's/>\s*//' | head -1)
        if [ -n "$target" ] && [ -f "$target" ] && ! is_safe_path "$target"; then
            warn_and_exit "覆盖已有文件" "文件: $target" "$input"
        fi
    fi

    # === 其他危险操作 ===
    if echo "$input" | grep -qE "dd\s+.*of="; then
        target=$(echo "$input" | grep -oE "of=[^\s]+" | sed 's/of=//')
        if [ -n "$target" ] && ! is_safe_path "$target"; then
            warn_and_exit "dd 写入" "目标: $target" "$input"
        fi
    fi
    if echo "$input" | grep -qE "chmod\s+777"; then
        warn_and_exit "权限过宽" "chmod 777 会给所有用户完全权限，存在安全风险" "$input"
    fi
    if echo "$input" | grep -qE "kill\s+-9|kill\s+-KILL|pkill\s+-9"; then
        warn_and_exit "强制杀进程" "kill -9 会强制终止进程，可能导致数据丢失" "$input"
    fi
}

if [ "$CLAUDE_TOOL_NAME" = "Bash" ]; then
    check_bash "$TOOL_INPUT"
fi

if [ "$CLAUDE_TOOL_NAME" = "Write" ]; then
    file_path=$(echo "$TOOL_INPUT" | jq -r '.file_path // empty' 2>/dev/null)
    if [ -n "$file_path" ]; then
        if echo "$file_path" | grep -qE "^/tmp/"; then
            warn_and_exit "写入 /tmp/" "文件: $file_path — 请使用项目目录或 /data/minimax-dialogue/data/users/<user>/"
        fi
        if [ -f "$file_path" ] && ! is_safe_path "$file_path"; then
            warn_and_exit "覆盖已有文件" "文件: $file_path (安全目录: output/, test_output/, debug_output/)"
        fi
    fi
fi

exit 0
