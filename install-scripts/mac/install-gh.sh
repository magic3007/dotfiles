#!/usr/bin/env bash
# =============================================================================
# macOS GitHub CLI Installation
# =============================================================================
# Install gh CLI using Homebrew

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { printf "${GREEN}[✓]${NC} %s\n" "$1"; }
warn()  { printf "${YELLOW}[!]${NC} %s\n" "$1"; }

# Check if already installed
if command -v gh >/dev/null 2>&1; then
    info "GitHub CLI already installed: $(gh --version 2>&1 | head -1)"
    exit 0
fi

# Install via Homebrew
if command -v brew >/dev/null 2>&1; then
    info "Installing GitHub CLI via Homebrew..."
    brew install gh || {
        warn "Failed to install GitHub CLI via Homebrew"
        info "Install manually: https://cli.github.com/"
        exit 1
    }
    info "GitHub CLI installed: $(gh --version 2>&1 | head -1)"
else
    warn "Homebrew not found. Install GitHub CLI manually: https://cli.github.com/"
    exit 1
fi
