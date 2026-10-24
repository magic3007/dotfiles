#!/usr/bin/env bash
# =============================================================================
# macOS GitHub CLI Installation
# =============================================================================
# Install gh CLI via Homebrew, falling back to the official release archive.
# The fallback covers hosts without Homebrew and hosts where brew cannot run
# (an unaccepted Xcode licence makes every brew command fail, because brew
# shells out to git). It installs into ~/.local/bin, which needs no root.
#
# The archive download resumes from a cache file, so a slow or flaky link
# makes progress across runs instead of starting over.
#
# Reference: https://github.com/cli/cli#installation

set -u

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { printf "${GREEN}[✓]${NC} %s\n" "$1"; }
warn()  { printf "${YELLOW}[!]${NC} %s\n" "$1"; }

BIN_DIR="$HOME/.local/bin"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles-gh"

install_from_release() {
    local arch version url layout zip attempt
    case "$(uname -m)" in
        arm64)  arch=arm64 ;;
        x86_64) arch=amd64 ;;
        *)
            warn "unsupported architecture: $(uname -m)"
            return 1
            ;;
    esac

    version=$(curl --connect-timeout 10 -fsSL -m 30 \
        https://api.github.com/repos/cli/cli/releases/latest 2>/dev/null |
        sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"v\([^"]*\)".*/\1/p' |
        head -n 1)
    if [ -z "$version" ]; then
        warn "cannot read the latest gh version from the GitHub API"
        return 1
    fi

    url="https://github.com/cli/cli/releases/download/v${version}/gh_${version}_macOS_${arch}.zip"
    mkdir -p "$CACHE_DIR" || return 1
    zip="$CACHE_DIR/gh_${version}_macOS_${arch}.zip"

    # A complete cached archive skips the transfer entirely.
    if [ -s "$zip" ] && unzip -tq "$zip" >/dev/null 2>&1; then
        info "Using cached archive: $zip"
    else
        info "Downloading gh ${version} (macOS ${arch})..."
        # -C - resumes an interrupted transfer; GitHub honours the Range header.
        attempt=1
        while [ "$attempt" -le 4 ]; do
            if curl --connect-timeout 20 -fL -C - --retry 3 --retry-delay 2 \
                    -m 240 -o "$zip" "$url"; then
                break
            fi
            warn "download interrupted (attempt $attempt/4); resuming"
            attempt=$((attempt + 1))
        done
        if [ ! -s "$zip" ]; then
            warn "download failed: $url"
            return 1
        fi
        # A truncated archive fails this test; drop it so the next run starts clean.
        if ! unzip -tq "$zip" >/dev/null 2>&1; then
            warn "archive is incomplete: $zip (delete it and re-run)"
            return 1
        fi
    fi

    layout=$(mktemp -d) || return 1
    if ! unzip -q "$zip" -d "$layout" ||
       [ ! -f "$layout/gh_${version}_macOS_${arch}/bin/gh" ]; then
        warn "unexpected archive layout: $zip"
        rm -rf "$layout"
        return 1
    fi

    mkdir -p "$BIN_DIR"
    install -m 755 "$layout/gh_${version}_macOS_${arch}/bin/gh" "$BIN_DIR/gh"
    # Man pages are optional; skip silently when the archive has none.
    if [ -d "$layout/gh_${version}_macOS_${arch}/share/man/man1" ]; then
        mkdir -p "$HOME/.local/share/man/man1"
        cp "$layout/gh_${version}_macOS_${arch}/share/man/man1/"*.1 \
            "$HOME/.local/share/man/man1/" 2>/dev/null || true
    fi
    rm -rf "$layout" "$zip"
    return 0
}

# Check if already installed
if command -v gh >/dev/null 2>&1; then
    info "GitHub CLI already installed: $(gh --version 2>&1 | head -1)"
    exit 0
fi

# Preferred path: Homebrew.
if command -v brew >/dev/null 2>&1; then
    info "Installing GitHub CLI via Homebrew..."
    if brew install gh && command -v gh >/dev/null 2>&1; then
        info "GitHub CLI installed: $(gh --version 2>&1 | head -1)"
        exit 0
    fi
    warn "Homebrew install failed; falling back to the official release archive"
else
    warn "Homebrew not found; using the official release archive"
fi

# Fallback: official release archive, no root required.
if install_from_release && [ -x "$BIN_DIR/gh" ]; then
    hash -r 2>/dev/null || true
    info "GitHub CLI installed: $("$BIN_DIR/gh" --version 2>&1 | head -n 1)"
    case ":$PATH:" in
        *":$BIN_DIR:"*) ;;
        *) warn "$BIN_DIR is not on PATH; add it so 'gh' resolves" ;;
    esac
    exit 0
fi

warn "Failed to install GitHub CLI"
warn "Install manually: https://cli.github.com/"
exit 1
