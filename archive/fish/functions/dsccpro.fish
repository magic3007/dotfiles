function dsccpro --description "Claude Code with DeepSeek Pro API"
    _claude_with_api "deepseek-v4-pro[1m]" "https://api.deepseek.com/anthropic" "$DEEPSEEK_API_KEY" $argv
end
