#!/usr/bin/env bash
# =============================================================================
# Linux System Packages Installation
# =============================================================================
# Install zsh, tmux, vim, htop, ranger without requiring sudo password
# Priority: sudo apt-get > mamba > conda > pip > skip

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
        return 1
    fi
}

install_with_apt() {
    info "Installing packages with sudo apt-get..."

    # Check sudo access first
    if ! can_sudo_without_password; then
        warn "No passwordless sudo, skipping apt installation"
        return 1
    fi

    if command -v timeout >/dev/null 2>&1; then
        run_sudo_noninteractive timeout 300 apt-get update || return 1
        run_sudo_noninteractive timeout 300 apt-get install -y zsh tmux vim htop ranger bubblewrap || return 1
    else
        run_sudo_noninteractive apt-get update || return 1
        run_sudo_noninteractive apt-get install -y zsh tmux vim htop ranger bubblewrap || return 1
    fi
}

install_with_mamba() {
    info "Trying mamba..."
    mamba install -y zsh tmux vim htop ranger 2>/dev/null || return 1
}

install_with_conda() {
    info "Trying conda..."
    conda install -y zsh tmux vim htop ranger 2>/dev/null || return 1
}

install_with_pip() {
    info "Trying pip for ranger..."
    pip install ranger-fm 2>/dev/null || return 1
}

main() {
    if [ "$(uname)" != "Linux" ]; then
        echo "Not Linux, skipping"
        exit 0
    fi

    # Check if already installed
    if command -v zsh >/dev/null 2>&1 && command -v tmux >/dev/null 2>&1 && \
       command -v vim >/dev/null 2>&1 && command -v htop >/dev/null 2>&1 && \
       command -v ranger >/dev/null 2>&1; then
        info "Core packages already installed"
    else
        # Try installation methods in order
        if can_sudo_without_password && install_with_apt; then
            info "Packages installed via apt"
        elif command -v mamba >/dev/null 2>&1 && install_with_mamba; then
            info "Packages installed via mamba"
        elif command -v conda >/dev/null 2>&1 && install_with_conda; then
            info "Packages installed via conda"
        elif command -v pip >/dev/null 2>&1 && install_with_pip; then
            info "ranger installed via pip"
        else
            warn "No passwordless sudo and no conda/mamba/pip available."
            warn "Skipping system packages installation."
            warn "You may need to ask admin to install: zsh tmux vim htop ranger"
        fi
    fi

    # Install Rust/Cargo
    install_rust

    # Install joshuto (not available in apt, use cargo)
    install_joshuto

    # Install RTK (Rust Token Killer) via cargo
    install_rtk

    info "Package installation complete"
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
    # Use Chinese mirror (rsproxy.cn) configured in common_shell_setup.sh
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

install_joshuto() {
    if command -v joshuto >/dev/null 2>&1; then
        info "joshuto already installed"
        return 0
    fi

    # Method 1: cargo install
    if command -v cargo >/dev/null 2>&1; then
        info "Installing joshuto via cargo..."
        cargo install --git https://github.com/kamiyaa/joshuto.git --force && return 0
        warn "cargo install failed, trying prebuilt binary..."
    fi

    # Method 2: download prebuilt binary from GitHub releases
    local arch
    arch="$(uname -m)"
    if [ "$arch" = "x86_64" ] || [ "$arch" = "aarch64" ]; then
        info "Downloading joshuto prebuilt binary..."
        # Query GitHub API to get latest version tag
        local version
        version="$(curl --connect-timeout 10 -sL "https://api.github.com/repos/kamiyaa/joshuto/releases" | grep -m1 '"tag_name"' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')"
        if [ -z "$version" ]; then
            warn "Failed to query joshuto latest version"
            return 1
        fi
        info "Latest joshuto version: ${version}"
        local tmp_dir
        tmp_dir="$(mktemp -d)"
        local download_url="https://github.com/kamiyaa/joshuto/releases/download/${version}/joshuto-${version}-${arch}-unknown-linux-gnu.tar.gz"
        if curl --connect-timeout 10 -fsSL "${download_url}" -o "${tmp_dir}/joshuto.tar.gz"; then
            tar -xzf "${tmp_dir}/joshuto.tar.gz" -C "${tmp_dir}"
            mkdir -p "$HOME/.local/bin"
            # Find the joshuto binary inside extracted directory
            local bin_path
            bin_path="$(find "${tmp_dir}" -name joshuto -type f | head -1)"
            if [ -n "$bin_path" ]; then
                cp "$bin_path" "$HOME/.local/bin/joshuto"
                chmod +x "$HOME/.local/bin/joshuto"
                info "joshuto installed to ~/.local/bin/joshuto"
            else
                warn "joshuto binary not found in archive"
            fi
        else
            warn "Failed to download joshuto prebuilt binary from ${download_url}"
        fi
        \rm -rf "${tmp_dir}"
    else
        warn "No prebuilt joshuto binary for arch ${arch}, need cargo to build from source"
    fi
}

install_rtk() {
    if command -v rtk >/dev/null 2>&1; then
        info "RTK (Rust Token Killer) already installed: $(rtk --version)"
        return 0
    fi

    if ! command -v cargo >/dev/null 2>&1; then
        warn "Cargo not found, cannot install RTK"
        return 1
    fi

    info "Installing RTK (Rust Token Killer) via cargo..."
    if cargo install rtk --locked; then
        info "RTK installed successfully"
    else
        warn "Failed to install RTK"
    fi
}

main "$@"
