#!/usr/bin/env bash
# =============================================================================
# Homebrew Installation for macOS
# =============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { printf "${GREEN}[✓]${NC} %s\n" "$1"; }
warn()  { printf "${YELLOW}[!]${NC} %s\n" "$1"; }

main() {
    if [ "$(uname)" != "Darwin" ]; then
        exit 0
    fi

    if command -v brew > /dev/null 2>&1; then
        info "Homebrew already installed"
        exit 0
    fi

    info "Installing Homebrew..."
    /bin/bash -c "$(curl --connect-timeout 10 -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add to PATH for this session
    if [ -f /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -f /usr/local/bin/brew ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi

    info "Homebrew installation complete"
}

main "$@"
