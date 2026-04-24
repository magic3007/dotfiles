function ccg --description "Claude Code via CC Gateway"
    set -l ccg_bin (find "$HOME/.cc-gateway/clients" -maxdepth 1 -type f -name "cc-*" | head -n 1)
    if test -n "$ccg_bin"
        env CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
            CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 \
            API_TIMEOUT_MS=600000 \
            $ccg_bin --dangerously-skip-permissions $argv
    else
        echo "No ccg client found in $HOME/.cc-gateway/clients/" >&2
        return 1
    end
end
