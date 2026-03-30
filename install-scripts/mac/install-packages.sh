#!/usr/bin/env bash
# =============================================================================
# macOS System Packages Installation
# =============================================================================
# Install packages using Homebrew

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { printf "${GREEN}[✓]${NC} %s\n" "$1"; }
warn()  { printf "${YELLOW}[!]${NC} %s\n" "$1"; }

install_homebrew() {
    if ! command -v brew >/dev/null 2>&1; then
        info "Installing Homebrew..."
        /bin/bash -c "$(curl --connect-timeout 10 -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        # Add to PATH for this session
        eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
    fi
}

install_packages() {
    info "Installing packages with Homebrew..."

    # Core packages
    local packages="rg lazygit zellij"

    for pkg in $packages; do
        if ! command -v "$pkg" >/dev/null 2>&1; then
            info "Installing $pkg..."
            brew install "$pkg" || warn "Failed to install $pkg"
        else
            info "$pkg already installed"
        fi
    done
}

main() {
    if [ "$(uname)" != "Darwin" ]; then
        echo "Not macOS, skipping"
        exit 0
    fi

    install_homebrew
    install_packages

    info "macOS package installation complete"
}

main "$@"
