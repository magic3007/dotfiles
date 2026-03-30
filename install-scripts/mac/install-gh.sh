#!/usr/bin/env bash
# =============================================================================
# GitHub CLI (gh) Installation for macOS
# =============================================================================
# Uses Homebrew

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { printf "${GREEN}[✓]${NC} %s\n" "$1"; }
warn()  { printf "${YELLOW}[!]${NC} %s\n" "$1"; }

main() {
    if [ "$(uname)" != "Darwin" ]; then
        echo "Not macOS, skipping"
        exit 0
    fi

    # Check if already installed
    if command -v gh >/dev/null 2>&1; then
        info "gh already installed: $(gh --version | head -1)"
        exit 0
    fi

    if ! command -v brew >/dev/null 2>&1; then
        warn "Homebrew not found. Please install Homebrew first."
        exit 1
    fi

    info "Installing gh with Homebrew..."
    brew install gh

    info "gh installation complete: $(gh --version | head -1)"
}

main "$@"
