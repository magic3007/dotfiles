function dscc --description "Claude Code with DeepSeek API"
    _claude_with_api "deepseek-v4-flash[1m]" "https://api.deepseek.com/anthropic" "$DEEPSEEK_API_KEY" $argv
end
