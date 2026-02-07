# Environment variables for OpenAI Codex
# Source this file to set up API key and other settings

# Load API key from config file if available
if [ -f ~/.codex/config.json ]; then
    # Extract API key from JSON (simple grep approach)
    CODEX_API_KEY=$(grep -o '"apiKey"[[:space:]]*:[[:space:]]*"[^"]*"' ~/.codex/config.json | cut -d'"' -f4)
    if [ -n "$CODEX_API_KEY" ] && [ "$CODEX_API_KEY" != "your-openai-api-key-here" ]; then
        export OPENAI_API_KEY="$CODEX_API_KEY"
    fi

    # Extract organization if present
    CODEX_ORG=$(grep -o '"organization"[[:space:]]*:[[:space:]]*"[^"]*"' ~/.codex/config.json | cut -d'"' -f4)
    if [ -n "$CODEX_ORG" ] && [ "$CODEX_ORG" != "optional-organization-id" ]; then
        export OPENAI_ORGANIZATION="$CODEX_ORG"
    fi
fi

# Load settings from settings.json if available
if [ -f ~/.codex/settings.json ]; then
    # Extract model
    CODEX_MODEL=$(grep -o '"defaultModel"[[:space:]]*:[[:space:]]*"[^"]*"' ~/.codex/settings.json | cut -d'"' -f4)
    if [ -n "$CODEX_MODEL" ]; then
        export CODEX_DEFAULT_MODEL="$CODEX_MODEL"
    fi

    # Extract temperature
    CODEX_TEMP=$(grep -o '"temperature"[[:space:]]*:[[:space:]]*[0-9.]*' ~/.codex/settings.json | cut -d':' -f2 | tr -d ' ')
    if [ -n "$CODEX_TEMP" ]; then
        export CODEX_TEMPERATURE="$CODEX_TEMP"
    fi
fi

# Alias for codex with common options
alias cx='codex'