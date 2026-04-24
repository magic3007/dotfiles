#!/usr/bin/env bash
# =============================================================================
# Offer to change default shell to zsh or fish
# =============================================================================
# Runs at the end of ./install to let the user pick their preferred shell.
# Only prompts if the current login shell differs from available options.

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { printf "${GREEN}[✓]${NC} %s\n" "$1"; }
warn()  { printf "${YELLOW}[!]${NC} %s\n" "$1"; }

current_shell=$(basename "$SHELL")

# Collect available shells
available=()
if command -v zsh >/dev/null 2>&1; then
    available+=(zsh)
fi
if command -v fish >/dev/null 2>&1; then
    available+=(fish)
fi

if [ ${#available[@]} -eq 0 ]; then
    exit 0
fi

# Filter out current shell — only offer shells the user isn't already using
options=()
for s in "${available[@]}"; do
    if [ "$current_shell" != "$s" ]; then
        options+=("$s")
    fi
done

if [ ${#options[@]} -eq 0 ]; then
    info "Current default shell is already $current_shell"
    exit 0
fi

echo ""
printf "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
printf "${CYAN}  Change default shell?${NC}\n"
printf "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
echo ""
printf "  Current login shell: ${YELLOW}%s${NC}\n" "$SHELL"
echo ""
echo "  Available options:"

idx=1
for s in "${options[@]}"; do
    shell_path=$(command -v "$s")
    printf "    ${GREEN}%d)${NC} %s (%s)\n" "$idx" "$s" "$shell_path"
    idx=$((idx + 1))
done
printf "    ${GREEN}%d)${NC} Keep current (%s)\n" "$idx" "$current_shell"
echo ""

read -p "  Choose [1-$idx] (default: keep current): " choice

# Default: keep current
if [ -z "$choice" ] || [ "$choice" = "$idx" ]; then
    info "Keeping current shell: $current_shell"
    exit 0
fi

# Validate choice
if [ "$choice" -lt 1 ] || [ "$choice" -ge "$idx" ] 2>/dev/null; then
    warn "Invalid choice, keeping current shell"
    exit 0
fi

selected="${options[$((choice - 1))]}"
selected_path=$(command -v "$selected")

if [ -z "$selected_path" ]; then
    warn "Could not find path for $selected"
    exit 1
fi

# Ensure the shell is in /etc/shells
if ! grep -qx "$selected_path" /etc/shells 2>/dev/null; then
    echo ""
    info "Adding $selected_path to /etc/shells (requires sudo)..."
    echo "$selected_path" | sudo tee -a /etc/shells >/dev/null
fi

# Change the default shell
info "Changing default shell to $selected ($selected_path)..."
chsh -s "$selected_path"
info "Default shell changed to $selected. Restart your terminal to take effect."
