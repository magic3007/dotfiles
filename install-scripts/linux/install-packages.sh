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
        run_sudo_noninteractive timeout 300 apt-get install -y zsh tmux vim htop ranger bubblewrap fish || return 1
    else
        run_sudo_noninteractive apt-get update || return 1
        run_sudo_noninteractive apt-get install -y zsh tmux vim htop ranger bubblewrap fish || return 1
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

    # Install lazygit (not available in apt, use prebuilt binary)
    install_lazygit

    # Install yazi (not available in apt, use cargo or prebuilt binary)
    install_yazi

    # Install joshuto (not available in apt, use cargo)
    install_joshuto

    # Install zoxide (smart cd)
    install_zoxide

    # Install fd (fast find alternative)
    install_fd

    # Install zellij (terminal multiplexer)
    install_zellij

    # Install RTK (Rust Token Killer) via cargo
    install_rtk

    # Install jd (JSON diff tool)
    install_jd

    # Install lsd (modern ls replacement)
    install_lsd

    # Install starship (cross-shell prompt)
    install_starship

    # Install bat (cat with syntax highlighting)
    install_bat

    # Install fastfetch (system information tool)
    install_fastfetch

    info "Package installation complete"
}

install_lazygit() {
    if command -v lazygit >/dev/null 2>&1; then
        info "lazygit already installed"
        return 0
    fi

    local arch
    arch="$(uname -m)"
    local lg_arch=""
    case "$arch" in
        x86_64)  lg_arch="Linux_x86_64" ;;
        aarch64) lg_arch="Linux_arm64" ;;
        *)       warn "No prebuilt lazygit binary for arch ${arch}"; return 1 ;;
    esac

    info "Downloading lazygit prebuilt binary..."
    local version
    version="$(curl --connect-timeout 10 -sL "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -m1 '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')"
    if [ -z "$version" ]; then
        warn "Failed to query lazygit latest version"
        return 1
    fi
    info "Latest lazygit version: ${version}"
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    local download_url="https://github.com/jesseduffield/lazygit/releases/download/v${version}/lazygit_${version}_${lg_arch}.tar.gz"
    if curl --connect-timeout 10 -fsSL "${download_url}" -o "${tmp_dir}/lazygit.tar.gz"; then
        tar -xzf "${tmp_dir}/lazygit.tar.gz" -C "${tmp_dir}"
        mkdir -p "$HOME/.local/bin"
        if [ -f "${tmp_dir}/lazygit" ]; then
            cp "${tmp_dir}/lazygit" "$HOME/.local/bin/lazygit"
            chmod +x "$HOME/.local/bin/lazygit"
            info "lazygit installed to ~/.local/bin/lazygit"
        else
            warn "lazygit binary not found in archive"
        fi
    else
        warn "Failed to download lazygit from ${download_url}"
    fi
    \rm -rf "${tmp_dir}"
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

install_yazi() {
    if command -v yazi >/dev/null 2>&1; then
        info "yazi already installed"
        return 0
    fi

    # Method 1: download prebuilt binary from GitHub releases
    local arch
    arch="$(uname -m)"
    if [ "$arch" = "x86_64" ] || [ "$arch" = "aarch64" ]; then
        info "Downloading yazi prebuilt binary..."
        local version
        version="$(curl --connect-timeout 10 -sL "https://api.github.com/repos/sxyazi/yazi/releases/latest" | grep -m1 '"tag_name"' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')"
        if [ -z "$version" ]; then
            warn "Failed to query yazi latest version"
        else
            info "Latest yazi version: ${version}"
            local tmp_dir
            tmp_dir="$(mktemp -d)"
            local download_url="https://github.com/sxyazi/yazi/releases/download/${version}/yazi-${arch}-unknown-linux-gnu.zip"
            if curl --connect-timeout 10 -fsSL "${download_url}" -o "${tmp_dir}/yazi.zip"; then
                unzip -q "${tmp_dir}/yazi.zip" -d "${tmp_dir}"
                mkdir -p "$HOME/.local/bin"
                local bin_path
                bin_path="$(find "${tmp_dir}" -name yazi -type f | head -1)"
                if [ -n "$bin_path" ]; then
                    cp "$bin_path" "$HOME/.local/bin/yazi"
                    chmod +x "$HOME/.local/bin/yazi"
                    info "yazi installed to ~/.local/bin/yazi"
                else
                    warn "yazi binary not found in archive"
                fi
            else
                warn "Failed to download yazi prebuilt binary"
            fi
            \rm -rf "${tmp_dir}"
            return 0
        fi
    fi

    # Method 2: cargo install
    if command -v cargo >/dev/null 2>&1; then
        info "Installing yazi via cargo..."
        cargo install --locked yazi-fm yazi-cli || warn "Failed to install yazi via cargo"
    else
        warn "No prebuilt yazi binary for arch ${arch:-unknown} and cargo not available"
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

install_zoxide() {
    if command -v zoxide >/dev/null 2>&1; then
        info "zoxide already installed"
        return 0
    fi

    info "Installing zoxide..."
    if curl --connect-timeout 10 -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh; then
        info "zoxide installed to ~/.local/bin/zoxide"
    else
        warn "Failed to install zoxide"
    fi
}

install_zellij() {
    if command -v zellij >/dev/null 2>&1; then
        info "zellij already installed"
        return 0
    fi

    local arch
    arch="$(uname -m)"
    local zj_arch=""
    case "$arch" in
        x86_64)  zj_arch="x86_64-unknown-linux-musl" ;;
        aarch64) zj_arch="aarch64-unknown-linux-musl" ;;
        *)       warn "No prebuilt zellij binary for arch ${arch}"; return 1 ;;
    esac

    info "Downloading zellij prebuilt binary..."
    local version
    version="$(curl --connect-timeout 10 -sL "https://api.github.com/repos/zellij-org/zellij/releases/latest" | grep -m1 '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')"
    if [ -z "$version" ]; then
        warn "Failed to query zellij latest version"
        return 1
    fi
    info "Latest zellij version: ${version}"
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    local download_url="https://github.com/zellij-org/zellij/releases/download/v${version}/zellij-${zj_arch}.tar.gz"
    if curl --connect-timeout 10 -fsSL "${download_url}" -o "${tmp_dir}/zellij.tar.gz"; then
        tar -xzf "${tmp_dir}/zellij.tar.gz" -C "${tmp_dir}"
        mkdir -p "$HOME/.local/bin"
        if [ -f "${tmp_dir}/zellij" ]; then
            cp "${tmp_dir}/zellij" "$HOME/.local/bin/zellij"
            chmod +x "$HOME/.local/bin/zellij"
            info "zellij installed to ~/.local/bin/zellij"
        else
            warn "zellij binary not found in archive"
        fi
    else
        warn "Failed to download zellij from ${download_url}"
    fi
    \rm -rf "${tmp_dir}"
}

install_fd() {
    if command -v fd >/dev/null 2>&1 || command -v fdfind >/dev/null 2>&1; then
        info "fd already installed"
        return 0
    fi

    local arch
    arch="$(uname -m)"
    local fd_arch=""
    case "$arch" in
        x86_64)  fd_arch="x86_64-unknown-linux-gnu" ;;
        aarch64) fd_arch="aarch64-unknown-linux-gnu" ;;
        *)       warn "No prebuilt fd binary for arch ${arch}"; return 1 ;;
    esac

    info "Downloading fd prebuilt binary..."
    local version
    version="$(curl --connect-timeout 10 -sL "https://api.github.com/repos/sharkdp/fd/releases/latest" | grep -m1 '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')"
    if [ -z "$version" ]; then
        warn "Failed to query fd latest version"
        return 1
    fi
    info "Latest fd version: ${version}"
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    local download_url="https://github.com/sharkdp/fd/releases/download/v${version}/fd-v${version}-${fd_arch}.tar.gz"
    if curl --connect-timeout 10 -fsSL "${download_url}" -o "${tmp_dir}/fd.tar.gz"; then
        tar -xzf "${tmp_dir}/fd.tar.gz" -C "${tmp_dir}"
        mkdir -p "$HOME/.local/bin"
        local bin_path
        bin_path="$(find "${tmp_dir}" -name fd -type f -executable | head -1)"
        if [ -n "$bin_path" ]; then
            cp "$bin_path" "$HOME/.local/bin/fd"
            chmod +x "$HOME/.local/bin/fd"
            info "fd installed to ~/.local/bin/fd"
        else
            warn "fd binary not found in archive"
        fi
    else
        warn "Failed to download fd from ${download_url}"
    fi
    \rm -rf "${tmp_dir}"
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

install_jd() {
    if command -v jd >/dev/null 2>&1; then
        info "jd already installed"
        return 0
    fi

    local arch
    arch="$(uname -m)"
    local jd_arch=""
    case "$arch" in
        x86_64)  jd_arch="amd64" ;;
        aarch64) jd_arch="arm64" ;;
        *)       warn "No prebuilt jd binary for arch ${arch}"; return 1 ;;
    esac

    info "Downloading jd prebuilt binary..."
    local version
    version="$(curl --connect-timeout 10 -sL "https://api.github.com/repos/josephburnett/jd/releases/latest" | grep -m1 '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')"
    if [ -z "$version" ]; then
        warn "Failed to query jd latest version"
        return 1
    fi
    info "Latest jd version: ${version}"
    local download_url="https://github.com/josephburnett/jd/releases/download/v${version}/jd-${jd_arch}-linux"
    mkdir -p "$HOME/.local/bin"
    if curl --connect-timeout 10 -fsSL "${download_url}" -o "$HOME/.local/bin/jd"; then
        chmod +x "$HOME/.local/bin/jd"
        info "jd installed to ~/.local/bin/jd"
    else
        warn "Failed to download jd from ${download_url}"
    fi
}

install_lsd() {
    if command -v lsd >/dev/null 2>&1; then
        info "lsd already installed"
        return 0
    fi

    local arch
    arch="$(uname -m)"
    local lsd_arch=""
    case "$arch" in
        x86_64)  lsd_arch="x86_64-unknown-linux-gnu" ;;
        aarch64) lsd_arch="aarch64-unknown-linux-gnu" ;;
        *)       warn "No prebuilt lsd binary for arch ${arch}"; return 1 ;;
    esac

    info "Downloading lsd prebuilt binary..."
    local version
    version="$(curl --connect-timeout 10 -sL "https://api.github.com/repos/lsd-rs/lsd/releases/latest" | grep -m1 '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')"
    if [ -z "$version" ]; then
        warn "Failed to query lsd latest version"
        return 1
    fi
    info "Latest lsd version: ${version}"
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    local download_url="https://github.com/lsd-rs/lsd/releases/download/v${version}/lsd-v${version}-${lsd_arch}.tar.gz"
    if curl --connect-timeout 10 -fsSL "${download_url}" -o "${tmp_dir}/lsd.tar.gz"; then
        tar -xzf "${tmp_dir}/lsd.tar.gz" -C "${tmp_dir}"
        mkdir -p "$HOME/.local/bin"
        local bin_path
        bin_path="$(find "${tmp_dir}" -name lsd -type f -executable | head -1)"
        if [ -n "$bin_path" ]; then
            cp "$bin_path" "$HOME/.local/bin/lsd"
            chmod +x "$HOME/.local/bin/lsd"
            info "lsd installed to ~/.local/bin/lsd"
        else
            warn "lsd binary not found in archive"
        fi
    else
        warn "Failed to download lsd from ${download_url}"
    fi
    \rm -rf "${tmp_dir}"
}

install_starship() {
    if command -v starship >/dev/null 2>&1; then
        info "starship already installed"
        return 0
    fi

    info "Installing starship..."
    mkdir -p "$HOME/.local/bin"
    if curl --connect-timeout 10 -fsSL https://starship.rs/install.sh | sh -s -- --yes --bin-dir "$HOME/.local/bin"; then
        info "starship installed to ~/.local/bin/starship"
    else
        warn "Failed to install starship"
    fi
}

install_bat() {
    if command -v bat >/dev/null 2>&1 || command -v batcat >/dev/null 2>&1; then
        info "bat already installed"
        return 0
    fi

    local arch
    arch="$(uname -m)"
    local bat_arch=""
    case "$arch" in
        x86_64)  bat_arch="x86_64-unknown-linux-gnu" ;;
        aarch64) bat_arch="aarch64-unknown-linux-gnu" ;;
        *)       warn "No prebuilt bat binary for arch ${arch}"; return 1 ;;
    esac

    info "Downloading bat prebuilt binary..."
    local version
    version="$(curl --connect-timeout 10 -sL "https://api.github.com/repos/sharkdp/bat/releases/latest" | grep -m1 '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')"
    if [ -z "$version" ]; then
        warn "Failed to query bat latest version"
        return 1
    fi
    info "Latest bat version: ${version}"
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    local download_url="https://github.com/sharkdp/bat/releases/download/v${version}/bat-v${version}-${bat_arch}.tar.gz"
    if curl --connect-timeout 10 -fsSL "${download_url}" -o "${tmp_dir}/bat.tar.gz"; then
        tar -xzf "${tmp_dir}/bat.tar.gz" -C "${tmp_dir}"
        mkdir -p "$HOME/.local/bin"
        local bin_path
        bin_path="$(find "${tmp_dir}" -name bat -type f -executable | head -1)"
        if [ -n "$bin_path" ]; then
            cp "$bin_path" "$HOME/.local/bin/bat"
            chmod +x "$HOME/.local/bin/bat"
            info "bat installed to ~/.local/bin/bat"
        else
            warn "bat binary not found in archive"
        fi
    else
        warn "Failed to download bat from ${download_url}"
    fi
    \rm -rf "${tmp_dir}"
}

install_fastfetch() {
    if command -v fastfetch >/dev/null 2>&1; then
        info "fastfetch already installed"
        return 0
    fi

    local arch
    arch="$(uname -m)"
    local ff_arch=""
    case "$arch" in
        x86_64)  ff_arch="linux-amd64" ;;
        aarch64) ff_arch="linux-aarch64" ;;
        *)       warn "No prebuilt fastfetch binary for arch ${arch}"; return 1 ;;
    esac

    info "Downloading fastfetch prebuilt binary..."
    local version
    version="$(curl --connect-timeout 10 -sL "https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest" | grep -m1 '"tag_name"' | sed 's/.*"\([^"]*\)".*/\1/')"
    if [ -z "$version" ]; then
        warn "Failed to query fastfetch latest version"
        return 1
    fi
    info "Latest fastfetch version: ${version}"
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    local download_url="https://github.com/fastfetch-cli/fastfetch/releases/download/${version}/fastfetch-${ff_arch}.tar.gz"
    if curl --connect-timeout 10 -fsSL "${download_url}" -o "${tmp_dir}/fastfetch.tar.gz"; then
        tar -xzf "${tmp_dir}/fastfetch.tar.gz" -C "${tmp_dir}"
        mkdir -p "$HOME/.local/bin"
        local bin_path
        bin_path="$(find "${tmp_dir}" -name fastfetch -type f -executable | head -1)"
        if [ -n "$bin_path" ]; then
            cp "$bin_path" "$HOME/.local/bin/fastfetch"
            chmod +x "$HOME/.local/bin/fastfetch"
            info "fastfetch installed to ~/.local/bin/fastfetch"
        else
            warn "fastfetch binary not found in archive"
        fi
    else
        warn "Failed to download fastfetch from ${download_url}"
    fi
    \rm -rf "${tmp_dir}"
}

main "$@"
