function cc --description "Claude Code with full permissions"
    env CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
        CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 \
        API_TIMEOUT_MS=600000 \
        claude --dangerously-skip-permissions $argv
end
