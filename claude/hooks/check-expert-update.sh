#!/bin/bash
# Hook script to remind updating documentation when related code changes
# Called by Claude Code PostToolUse hook

# Check if jq is available
if ! command -v jq &> /dev/null; then
    exit 0
fi

# Read JSON input from stdin
INPUT=$(cat)

# Extract file path from tool input
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [ -z "$FILE_PATH" ]; then
    exit 0
fi

# Define mappings: code path pattern -> documentation to update
check_doc_update() {
    local file="$1"
    local reminder=""
    local reminder_desc=""

    # Configuration files
    if [[ "$file" == *".json" ]] || [[ "$file" == *".yaml" ]] || [[ "$file" == *".yml" ]] || [[ "$file" == *".toml" ]]; then
        reminder="Configuration files"
        reminder_desc="Check if configuration changes require documentation updates"
    fi

    # Documentation files themselves
    if [[ "$file" == *"README"* ]] || [[ "$file" == *".md" ]] || [[ "$file" == *".rst" ]] || [[ "$file" == *".txt" ]]; then
        reminder="Documentation"
        reminder_desc="Documentation was modified, ensure related code comments are consistent"
    fi

    # Script files
    if [[ "$file" == *".sh" ]] || [[ "$file" == *".bash" ]] || [[ "$file" == *".zsh" ]]; then
        reminder="Shell scripts"
        reminder_desc="Update usage instructions or script documentation if needed"
    fi

    # Python files
    if [[ "$file" == *".py" ]]; then
        reminder="Python code"
        reminder_desc="Check if API changes require docstring updates or documentation"
    fi

    # Output reminder if matched
    if [ -n "$reminder" ]; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📝 Documentation Update Reminder"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Modified: $file"
        echo "Category: $reminder"
        echo "Action: $reminder_desc"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
    fi
}

check_doc_update "$FILE_PATH"
