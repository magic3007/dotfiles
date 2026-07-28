#!/usr/bin/env bash
# =============================================================================
# Linux GitHub CLI Installation
# =============================================================================
# Install gh CLI using the official GitHub CLI repository
# Ref: https://github.com/cli/cli/blob/trunk/docs/install_linux.md

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

# Detect package manager and install
if command -v apt-get >/dev/null 2>&1; then
    info "Installing GitHub CLI via apt (official GitHub repository)..."

    # Check for passwordless sudo
    if ! sudo -n true 2>/dev/null; then
        warn "No passwordless sudo, skipping GitHub CLI installation"
        info "Install manually: https://cli.github.com/"
        exit 1
    fi

    # Install GitHub CLI using the official install script
    if curl --connect-timeout 10 -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null; then
        sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
            | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        sudo apt-get update -qq
        sudo apt-get install -y gh
        info "GitHub CLI installed: $(gh --version 2>&1 | head -1)"
    else
        warn "Failed to add GitHub CLI repository, trying apt fallback..."
        # Some Ubuntu/Debian versions include gh in the default repos
        sudo apt-get install -y gh || {
            warn "Failed to install GitHub CLI via apt"
            info "Install manually: https://cli.github.com/"
            exit 1
        }
    fi
elif command -v yum >/dev/null 2>&1; then
    info "Installing GitHub CLI via yum..."
    sudo dnf install -y 'dnf-command(config-manager)' 2>/dev/null || true
    sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo 2>/dev/null || \
        sudo yum install -y yum-utils 2>/dev/null && sudo yum-config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
    sudo dnf install -y gh || sudo yum install -y gh || {
        warn "Failed to install GitHub CLI via yum/dnf"
        info "Install manually: https://cli.github.com/"
        exit 1
    }
    info "GitHub CLI installed: $(gh --version 2>&1 | head -1)"
else
    warn "Unsupported package manager. Install GitHub CLI manually: https://cli.github.com/"
    exit 1
fi
