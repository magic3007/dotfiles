#!/usr/bin/env bash
# =============================================================================
# Dotfiles One-Click Bootstrap Script
# =============================================================================
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/magic3007/dotfiles/master/bootstrap.sh)
#
# What this script does:
#   1. Set up SSH key for GitHub
#   2. Install Claude Code CLI + configure API (VolcEngine by default)
#   3. Launch Claude Code to clone dotfiles & complete setup
# =============================================================================

set -e

# ---------------------------------------------------------------------------
# Colors & helpers
# ---------------------------------------------------------------------------
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info()  { printf "${GREEN}[✓]${NC} %s\n" "$1"; }
warn()  { printf "${YELLOW}[!]${NC} %s\n" "$1"; }
err()   { printf "${RED}[✗]${NC} %s\n" "$1"; exit 1; }
ask()   { printf "${BLUE}[?]${NC} %s " "$1"; }
title() { printf "\n${BOLD}══════ %s ══════${NC}\n\n" "$1"; }

# ===========================================================================
# Welcome & Summary
# ===========================================================================
title "magic3007/dotfiles One-Click Bootstrap"

echo ""
echo "Installation Flow:"
echo ""
echo "  1. 🔑 SSH Key    - Check or generate SSH key for GitHub"
echo "  2. 🛠️  Install   - Install Node.js + Claude Code CLI"
echo "  3. ⚙️  Configure - Set up Claude Code API (VolcEngine by default)"
echo "  4. 🚀 Dotfiles  - Clone repo and run full dotfiles installation"
echo "  5. ✅ Verify    - Launch Claude Code to verify and troubleshoot"
echo ""
echo "Default API Settings:"
echo "    ANTHROPIC_BASE_URL = https://ark.cn-beijing.volces.com/api/coding"
echo "    ANTHROPIC_MODEL    = doubao-seed-2.0-lite"
echo "    Authentication    = from \$VE_CODE_API_KEY environment variable"
echo ""

ask "Continue with installation? [Y/n]"; read -r yn
case "$yn" in [nN]*) err "Aborted." ;; esac

# ===========================================================================
# Step 1: SSH Key
# ===========================================================================
title "Step 1/5: SSH Key Setup"

mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"

if [ -f "$HOME/.ssh/id_ed25519" ]; then
    info "Found existing SSH key (~/.ssh/id_ed25519)"
    SSH_PUB="$HOME/.ssh/id_ed25519.pub"
elif [ -f "$HOME/.ssh/id_rsa" ]; then
    info "Found existing SSH key (~/.ssh/id_rsa)"
    SSH_PUB="$HOME/.ssh/id_rsa.pub"
else
    warn "No SSH key found, generating a new ed25519 key..."
    ask "Enter email for SSH key:"; read -r ssh_email
    ssh-keygen -t ed25519 -C "${ssh_email}" -f "$HOME/.ssh/id_ed25519" -N ""
    eval "$(ssh-agent -s)" >/dev/null 2>&1
    ssh-add "$HOME/.ssh/id_ed25519" 2>/dev/null || true
    SSH_PUB="$HOME/.ssh/id_ed25519.pub"
    info "SSH key generated"
fi

echo ""
warn "Please add this public key to GitHub:"
warn "  → https://github.com/settings/keys"
echo ""
echo "-------- PUBLIC KEY --------"
cat "$SSH_PUB"
echo "----------------------------"
echo ""
ask "Press Enter after adding the key to GitHub..."; read -r

# Test SSH connection
if ssh -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 | grep -qi "success"; then
    info "GitHub SSH connection verified!"
else
    warn "Could not verify GitHub SSH. You may need to add the key."
    ask "Continue anyway? [Y/n]"; read -r yn
    case "$yn" in [nN]*) err "Aborted." ;; esac
fi

# ===========================================================================
# Step 2: Install Node.js & Claude Code
# ===========================================================================
title "Step 2/5: Install Claude Code"

# -- Node.js via nvm --
if ! command -v node &>/dev/null; then
    info "Installing nvm + Node.js LTS..."
    export NVM_DIR="$HOME/.nvm"
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    nvm install --lts
    info "Node.js installed: $(node --version)"
else
    info "Node.js already installed: $(node --version)"
fi

# -- Claude Code --
# Ensure nvm is loaded in current shell
export NVM_DIR="$HOME/.nvm"
# shellcheck source=/dev/null
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
# Add user npm global bin to PATH for non-root installs
export PATH="$HOME/.npm-global/bin:$PATH"

if ! command -v claude &>/dev/null; then
    info "Installing Claude Code..."
    # Install to user directory to avoid requiring root permissions
    npm config set prefix "$HOME/.npm-global"
    export PATH="$HOME/.npm-global/bin:$PATH"
    npm install -g @anthropic-ai/claude-code --prefix "$HOME/.npm-global"
    # Add to PATH in local setup if not already there
    if ! grep -q "npm-global/bin" "$LOCAL_SETUP" 2>/dev/null; then
        printf '\n# Add npm global bin to PATH (user install)\nexport PATH="$HOME/.npm-global/bin:$PATH"\n' >> "$LOCAL_SETUP"
    fi
    info "Claude Code installed to ~/.npm-global"
else
    info "Claude Code already installed"
fi

# Verify
command -v claude &>/dev/null || err "Claude Code not found in PATH. Please check installation."

# ===========================================================================
# Step 3: Configure API Settings
# ===========================================================================
title "Step 3/5: Configure Claude Code API"

DEFAULT_BASE_URL="https://ark.cn-beijing.volces.com/api/coding"
DEFAULT_MODEL="doubao-seed-2.0-lite"

echo "Default: VolcEngine Coding Plan (doubao-seed-2.0-lite)"
echo ""

ask "ANTHROPIC_BASE_URL [${DEFAULT_BASE_URL}]:"; read -r input_base_url
ANTHROPIC_BASE_URL="${input_base_url:-$DEFAULT_BASE_URL}"

ask "ANTHROPIC_MODEL [${DEFAULT_MODEL}]:"; read -r input_model
ANTHROPIC_MODEL="${input_model:-$DEFAULT_MODEL}"

echo ""
echo "ANTHROPIC_AUTH_TOKEN: leave empty to use \$VE_CODE_API_KEY env var,"
echo "  or enter a token directly."
ask "ANTHROPIC_AUTH_TOKEN [use \$VE_CODE_API_KEY]:"; read -r input_token

# -- Prepare ~/.common_shell_setup_local.sh --
LOCAL_SETUP="$HOME/.common_shell_setup_local.sh"
touch "$LOCAL_SETUP"

if [ -z "$input_token" ]; then
    # Source existing config
    # shellcheck source=/dev/null
    source "$LOCAL_SETUP" 2>/dev/null || true

    if [ -z "${VE_CODE_API_KEY:-}" ]; then
        ask "Enter your VE_CODE_API_KEY:"; read -r ve_key
        [ -z "$ve_key" ] && err "VE_CODE_API_KEY cannot be empty."
        printf '\n# VolcEngine Code API Key (added by bootstrap)\nexport VE_CODE_API_KEY="%s"\n' "$ve_key" >> "$LOCAL_SETUP"
        export VE_CODE_API_KEY="$ve_key"
        info "VE_CODE_API_KEY saved to $LOCAL_SETUP"
    else
        info "VE_CODE_API_KEY already set"
    fi
    RESOLVED_TOKEN="$VE_CODE_API_KEY"
else
    RESOLVED_TOKEN="$input_token"
fi

# -- FEISHU_WEBHOOK_URL placeholder for wechat-reminder --
if ! grep -q "FEISHU_WEBHOOK_URL" "$LOCAL_SETUP" 2>/dev/null; then
    printf '\n# WeChat Reminder webhook URL (fill in your actual URL)\nexport FEISHU_WEBHOOK_URL=""\n' >> "$LOCAL_SETUP"
    info "FEISHU_WEBHOOK_URL placeholder added to $LOCAL_SETUP"
fi

# -- Gather git user info --
echo ""
# Check existing git configuration (try global, then local config file)
existing_name=$(git config --global user.name 2>/dev/null || true)
existing_email=$(git config --global user.email 2>/dev/null || true)

# Also check ~/.gitconfig_local which is included by the dotfiles gitconfig
GIT_CONFIG_LOCAL="$HOME/.gitconfig_local"
if [ -z "$existing_name" ] && [ -f "$GIT_CONFIG_LOCAL" ]; then
    existing_name=$(git config -f "$GIT_CONFIG_LOCAL" user.name 2>/dev/null || true)
    existing_email=$(git config -f "$GIT_CONFIG_LOCAL" user.email 2>/dev/null || true)
fi

if [ -n "$existing_name" ] && [ -n "$existing_email" ]; then
    info "Found existing git configuration:"
    info "  user.name  = $existing_name"
    info "  user.email = $existing_email"
    ask "Would you like to update it? [y/N]"; read -r update_yn
    case "$update_yn" in
        [yY]*)
            ask "Git user.name:"; read -r git_name
            ask "Git user.email:"; read -r git_email
            ;;
        *)
            git_name="$existing_name"
            git_email="$existing_email"
            info "Keeping existing git configuration"
            ;;
    esac
else
    ask "Git user.name (for ~/.gitconfig_local):"; read -r git_name
    ask "Git user.email:"; read -r git_email
fi

[ -z "$RESOLVED_TOKEN" ] && err "No API token configured. Cannot continue."
info "API configuration complete"

# ===========================================================================
# Step 4: Launch Claude Code to complete setup
# ===========================================================================
title "Step 4/4: Claude Code Dotfiles Setup"

info "Launching Claude Code to clone dotfiles & run installer..."
echo ""

# ===========================================================================
# Step 4: Clone & Run dotfiles install directly (faster for long-running install)
# ===========================================================================
title "Step 4/5: Clone & Install Dotfiles"

# Clone repo if not exists
DEFAULT_DOTFILES_DIR="$HOME/dotfiles"
ask "Dotfiles directory [${DEFAULT_DOTFILES_DIR}]:"; read -r input_dotfiles_dir
DOTFILES_DIR="${input_dotfiles_dir:-$DEFAULT_DOTFILES_DIR}"

# Expand ~ to $HOME
DOTFILES_DIR="${DOTFILES_DIR/#\~/$HOME}"

if [ ! -d "$DOTFILES_DIR" ]; then
    info "Cloning dotfiles to ${DOTFILES_DIR}..."
    git clone --recursive https://github.com/magic3007/dotfiles.git "$DOTFILES_DIR"
else
    info "${DOTFILES_DIR} already exists, skipping clone"
fi

# Run the main install
cd "$DOTFILES_DIR"
echo ""
warn "Running full dotfiles installation..."
warn "  - This includes: Homebrew (macOS), oh-my-zsh, fzf, GitHub CLI, wechat-reminder, etc."
warn "  - Depending on your network speed, this takes **3-10 minutes**"
warn "  - Failed network operations won't block the installation\n"

# Capture install output to file for later analysis
INSTALL_LOG="$HOME/.cache/dotfiles_install_$$.log"
mkdir -p "$HOME/.cache"
info "Running install with output capture to $INSTALL_LOG"

# Capture output to log while also displaying on screen
./install 2>&1 | tee "$INSTALL_LOG" || true

echo ""
info "Dotfiles install completed (any failed steps can be manually retried later)"

# Write git local config
GIT_CONFIG_LOCAL="$HOME/.gitconfig_local"
if [ -n "$git_name" ] && [ -n "$git_email" ]; then
    if [ -f "$GIT_CONFIG_LOCAL" ]; then
        # Check if user actually changed it
        if [ "$git_name" != "$existing_name" ] || [ "$git_email" != "$existing_email" ]; then
            info "Updating ~/.gitconfig_local with new git user info"
            cat > "$GIT_CONFIG_LOCAL" <<EOF
[user]
    name = ${git_name}
    email = ${git_email}
EOF
        else
            info "Git configuration unchanged"
        fi
    else
        info "Creating ~/.gitconfig_local with your git user info"
        cat > "$GIT_CONFIG_LOCAL" <<EOF
[user]
    name = ${git_name}
    email = ${git_email}
EOF
    fi
fi

# ===========================================================================
# Launch Claude Code for final verification & troubleshooting (interactive)
# ===========================================================================
info "\nLaunching Claude Code for final check...\n"

INSTALL_LOG_PATH="$INSTALL_LOG"
SETUP_PROMPT="The ./install command just completed. I have captured the full output to a log file.

Your task: Read the install log at $INSTALL_LOG_PATH, analyze what failed, and fix the issues.

Follow these steps:

1. Read the log file: cat $INSTALL_LOG_PATH

2. Identify failed operations by looking for:
   - 'git command failed' (plugin clones)
   - 'Some tasks were not executed successfully' (dotbot summary)
   - 'fatal:' or 'error:' messages
   - 'command not found' (missing packages)
   - Network timeout errors

3. For each failure found, fix it:
   - Failed git clones: Retry them with 'git clone --recursive'
   - Missing oh-my-zsh plugins: Clone to ~/.oh-my-zsh/custom/plugins/
   - Missing packages: Install with 'brew install' (macOS) or 'apt-get install' (Linux)
   - fzf not installed properly: Run ~/.fzf/install
   - Missing AI CLIs: Re-run the npm install or curl commands

4. Verify critical components work:
   - ls ~/.oh-my-zsh/custom/plugins/
   - command -v fzf
   - command -v claude codex gemini opencode
   - command -v wechat-reminder

5. Report what you found and what you fixed.

Start by reading the log file, then proceed with fixes. No need to ask for confirmation."



# Launch Claude Code like sdcc() does (interactive mode with initial prompt)
env -u ANTHROPIC_API_KEY \
    ANTHROPIC_BASE_URL="$ANTHROPIC_BASE_URL" \
    ANTHROPIC_AUTH_TOKEN="$RESOLVED_TOKEN" \
    API_TIMEOUT_MS=600000 \
    ANTHROPIC_MODEL="$ANTHROPIC_MODEL" \
    ANTHROPIC_SMALL_FAST_MODEL="$ANTHROPIC_MODEL" \
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
    claude "$SETUP_PROMPT" --dangerously-skip-permissions

# Clean up install log
rm -f "$INSTALL_LOG"

echo ""
info "========================================="
info "  Bootstrap complete!"
info "========================================="
echo ""
echo "  Restart your shell or run:"
echo "    source ~/.zshrc    # if using zsh"
echo "    source ~/.bashrc   # if using bash"
echo ""
echo "  Then use 'sdcc' to start Claude Code:"
echo "    sdcc"
echo ""
echo "  Other useful aliases:"
echo "    cc   - Claude Code (native API)"
echo "    dscc - Claude Code + DeepSeek"
echo "    kmcc - Claude Code + Kimi"
echo ""
echo "  Configure wechat-reminder:"
echo "    Edit ~/.common_shell_setup_local.sh and set FEISHU_WEBHOOK_URL"
echo ""
