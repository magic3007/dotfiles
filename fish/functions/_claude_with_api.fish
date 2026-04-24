function _claude_with_api --description "Run Claude Code with custom API backend"
    set -l m $argv[1]
    set -l url $argv[2]
    set -l token $argv[3]
    set -e argv[1..3]

    env -u ANTHROPIC_API_KEY \
        ANTHROPIC_BASE_URL=$url \
        ANTHROPIC_AUTH_TOKEN=$token \
        API_TIMEOUT_MS=600000 \
        ANTHROPIC_MODEL=$m \
        ANTHROPIC_DEFAULT_SONNET_MODEL=$m \
        ANTHROPIC_DEFAULT_OPUS_MODEL=$m \
        ANTHROPIC_DEFAULT_HAIKU_MODEL=$m \
        ANTHROPIC_SMALL_FAST_MODEL=$m \
        CLAUDE_CODE_SUBAGENT_MODEL=$m \
        CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
        CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 \
        claude $argv --dangerously-skip-permissions
end
