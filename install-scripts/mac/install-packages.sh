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
    local packages="rg lazygit zellij ranger joshuto"

    for pkg in $packages; do
        if ! command -v "$pkg" >/dev/null 2>&1; then
            info "Installing $pkg..."
            brew install "$pkg" || warn "Failed to install $pkg"
        else
            info "$pkg already installed"
        fi
    done
}

install_ghostty() {
    if [ -d "/Applications/Ghostty.app" ]; then
        info "Ghostty already installed"
        return 0
    fi

    info "Installing Ghostty..."
    brew install --cask ghostty || warn "Failed to install Ghostty"
}

install_rust() {
    if command -v rustup >/dev/null 2>&1; then
        # Ensure default toolchain is set
        if ! rustup default >/dev/null 2>&1; then
            info "Setting Rust default toolchain to stable..."
            rustup default stable
        fi
        source "$HOME/.cargo/env"
        if command -v cargo >/dev/null 2>&1; then
            info "Rust/Cargo already installed"
            return 0
        fi
    fi

    info "Installing Rust via rustup..."
    export RUSTUP_DIST_SERVER="https://rsproxy.cn"
    export RUSTUP_UPDATE_ROOT="https://rsproxy.cn/rustup"
    if curl --connect-timeout 10 -fsSL https://rsproxy.cn/rustup-init.sh | sh -s -- -y --no-modify-path; then
        source "$HOME/.cargo/env"
        info "Setting Rust default toolchain to stable..."
        rustup default stable
        info "Rust installed: $(rustc --version)"
    else
        warn "Failed to install Rust"
    fi
}

install_rtk() {
    if command -v rtk >/dev/null 2>&1; then
        info "RTK (Rust Token Killer) already installed: $(rtk --version)"
        return 0
    fi

    info "Installing RTK (Rust Token Killer) via Homebrew..."
    if brew install rtk; then
        info "RTK installed successfully"
    else
        warn "Failed to install RTK"
    fi
}

main() {
    if [ "$(uname)" != "Darwin" ]; then
        echo "Not macOS, skipping"
        exit 0
    fi

    install_homebrew
    install_rust
    install_packages
    install_ghostty
    install_rtk

    info "macOS package installation complete"
}

main "$@"
