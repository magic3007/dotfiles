#!/usr/bin/env bash
# =============================================================================
# GitHub CLI (gh) Installation for Linux
# =============================================================================
# Priority: sudo apt-get > conda/mamba > binary download to ~/.local/bin

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { printf "${GREEN}[✓]${NC} %s\n" "$1"; }
warn()  { printf "${YELLOW}[!]${NC} %s\n" "$1"; }

# Check if we can run sudo without password
can_sudo_without_password() {
    sudo -n true 2>/dev/null
}

# Run sudo with timeout, fail if password required
run_sudo_noninteractive() {
    if can_sudo_without_password; then
        sudo "$@"
    else
        warn "sudo requires password, skipping apt method"
        return 1
    fi
}

install_with_apt() {
    info "Installing gh with sudo apt-get..."

    # Check sudo access first
    if ! can_sudo_without_password; then
        warn "No passwordless sudo, skipping apt installation"
        return 1
    fi

    # Install wget if needed (non-interactive)
    if ! command -v wget >/dev/null 2>&1; then
        run_sudo_noninteractive apt-get update || return 1
        run_sudo_noninteractive apt-get install -y wget || return 1
    fi

    # Add GitHub CLI repository
    run_sudo_noninteractive mkdir -p -m 755 /etc/apt/keyrings || return 1
    wget --timeout=10 -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
        run_sudo_noninteractive tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null || return 1
    run_sudo_noninteractive chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg || return 1

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
        run_sudo_noninteractive tee /etc/apt/sources.list.d/github-cli.list >/dev/null || return 1

    run_sudo_noninteractive apt-get update || return 1
    run_sudo_noninteractive apt-get install -y gh || return 1
}

install_with_conda() {
    info "Trying conda/mamba..."
    if command -v mamba >/dev/null 2>&1; then
        mamba install -y gh 2>/dev/null
    elif command -v conda >/dev/null 2>&1; then
        conda install -y gh 2>/dev/null
    else
        return 1
    fi
}

install_binary() {
    info "Installing gh binary to ~/.local/bin..."

    mkdir -p ~/.local/bin

    local tmpdir arch download_url
    tmpdir=$(mktemp -d)
    # shellcheck disable=SC2064
    trap "rm -rf $tmpdir" EXIT

    # Detect architecture
    arch=$(uname -m)
    case "$arch" in
        x86_64)  arch="amd64" ;;
        aarch64) arch="arm64" ;;
        arm64)   arch="arm64" ;;
    esac

    # Use GitHub API to get latest release URL with timeout
    download_url="https://github.com/cli/cli/releases/latest/download/gh_linux_${arch}.tar.gz"

    info "Downloading from: $download_url"
    curl --connect-timeout 10 --max-time 60 -fsSL "$download_url" | tar -xz -C "$tmpdir" || {
        warn "Failed to download gh binary"
        return 1
    }

    # Find and move the binary
    if [ -f "$tmpdir/gh_"*/bin/gh ]; then
        mv "$tmpdir"/gh_*/bin/gh ~/.local/bin/
        chmod +x ~/.local/bin/gh
        info "gh installed to ~/.local/bin/gh"
    else
        warn "Could not find gh binary in downloaded archive"
        return 1
    fi
}

main() {
    if [ "$(uname)" != "Linux" ]; then
        echo "Not Linux, skipping"
        exit 0
    fi

    # Check if already installed
    if command -v gh >/dev/null 2>&1; then
        info "gh already installed: $(gh --version | head -1)"
        exit 0
    fi

    # Try installation methods in order
    if can_sudo_without_password && install_with_apt; then
        info "gh installed via apt"
    elif install_with_conda; then
        info "gh installed via conda/mamba"
    elif install_binary; then
        info "gh installed via binary"
    else
        warn "All installation methods failed. You can manually install gh later."
        # Don't fail the whole installation
        exit 0
    fi

    # Verify installation
    if command -v gh >/dev/null 2>&1; then
        info "gh installation verified: $(gh --version | head -1)"
    else
        warn "gh may not be in PATH. Add ~/.local/bin to your PATH."
    fi
}

main "$@"
