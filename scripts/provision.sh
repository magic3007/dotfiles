#!/usr/bin/env bash
# Install the tools the configs are for. Network, ./install only (never the
# 15-minute sync). Every step skips what is already installed and a failing step
# never stops the rest; the exit status is non-zero when any failed.
#
# ~/.zshrc and ~/.bashrc are links into this repository, so an installer that
# appends PATH lines would edit tracked files. Third-party installers run with
# SHELL=/bin/none and PROFILE=/dev/null and their own no-rc flag where they have
# one; the Antigravity CLI ignores all of those, so it installs under a
# throwaway HOME with --dir pointing at the real ~/.local/bin.
#
# PATH starts with the user tool directories, so a tool installed there counts
# as installed whatever environment ./install was started from.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
PATH="$HOME/.local/bin:$HOME/.bun/bin:$HOME/.opencode/bin:$HOME/.kimi-code/bin:$HOME/.fzf/bin:$PATH"
status=0

step() {
    printf -- '--> %s\n' "$1"
    shift
    "$@" || { printf 'warn  step failed: %s\n' "$*" >&2; status=1; }
}

quiet_rc() { SHELL=/bin/none PROFILE=/dev/null "$@"; }
fetch() { curl --connect-timeout 30 -fsSL "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }
load_nvm() {
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
}

clone_or_pull() {
    if [ -d "$2/.git" ]; then
        git -C "$2" pull --ff-only --quiet
    else
        git clone --depth 1 --quiet "$1" "$2"
    fi
}

install_oh_my_zsh() {
    [ -d "$HOME/.oh-my-zsh" ] ||
        fetch https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh |
        CHSH=no RUNZSH=no KEEP_ZSHRC=yes sh || return 1
    local plugins="$HOME/.oh-my-zsh/custom/plugins" repo
    for repo in zsh-users/zsh-syntax-highlighting zsh-users/zsh-autosuggestions \
        wbinglee/zsh-wakatime wting/autojump jeffreytse/zsh-vi-mode; do
        clone_or_pull "https://github.com/$repo.git" "$plugins/${repo#*/}" || return 1
    done
    [ -d "$HOME/.autojump" ] || (cd "$plugins/autojump" && SHELL=/bin/zsh ./install.py >/dev/null)
}

install_fzf() {
    clone_or_pull https://github.com/junegunn/fzf.git "$HOME/.fzf" &&
        "$HOME/.fzf/install" --key-bindings --completion --no-update-rc
}

install_node() {
    load_nvm || fetch https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | quiet_rc bash
    load_nvm && nvm install --lts >/dev/null
}

install_npm_tools() {
    load_nvm
    have npm || { echo "npm missing; the Node.js step failed" >&2; return 1; }
    local entry
    for entry in claude:@anthropic-ai/claude-code codex:@openai/codex dsh:@deepseek-ai/dsh \
        mgrep:@mixedbread/mgrep happy:happy; do
        have "${entry%%:*}" || npm install -g "${entry#*:}@latest" || return 1
    done
    have codexapp || npm install -g codexapp@latest firebase@latest || return 1
    have pi || npm install -g --ignore-scripts @earendil-works/pi-coding-agent || return 1
    for entry in pi-powerline-footer@0.12.2 pi-web-access pi-herdr-agents; do
        pi install "npm:$entry" || return 1
    done
    have lark-cli || npx --yes @larksuite/cli@latest install
}

install_curl_tools() {
    have agy || install_agy || return 1
    have opencode || fetch https://opencode.ai/install | quiet_rc bash || return 1
    have kimi || fetch https://code.kimi.com/kimi-code/install.sh | quiet_rc bash || return 1
    have uv || fetch https://astral.sh/uv/install.sh | UV_NO_MODIFY_PATH=1 quiet_rc sh || return 1
    uv python install 3.12 3.11 3.10 &&
        { [ -d "$HOME/.venv" ] || uv venv --python 3.12 --prompt base --seed "$HOME/.venv"; }
}

install_agy() {
    local home rc
    home="$(mktemp -d)"
    fetch https://antigravity.google/cli/install.sh | HOME="$home" bash -s -- --dir "$HOME/.local/bin"
    rc=$?
    command rm -rf "$home"
    return "$rc"
}

install_wechat_reminder() {
    local dest="$HOME/.wechat-reminder"
    mkdir -p "$dest" &&
        cp wechat-reminder/{wechat-reminder,wechat-reminder_main.py,requirements.txt,LICENSE} "$dest/" &&
        chmod +x "$dest/wechat-reminder" "$dest/wechat-reminder_main.py" &&
        python3 -m venv "$dest/.venv" &&
        "$dest/.venv/bin/pip" install -q -r "$dest/requirements.txt"
}

install_omp() {
    have bun || [ -x "$HOME/.bun/bin/bun" ] || fetch https://bun.sh/install | quiet_rc bash || return 1
    PATH="$HOME/.bun/bin:$PATH"
    have omp || fetch https://omp.sh/install | quiet_rc sh || return 1
    bash scripts/omp-plugins.sh
}

install_herdr() {
    have herdr || fetch https://herdr.dev/install.sh | quiet_rc sh || return 1
    bash scripts/herdr-plugin-link.sh || return 1
    ! have omp || herdr integration install omp
}

step "system packages (Linux)" bash scripts/packages-linux.sh
step "system packages (macOS)" bash scripts/packages-mac.sh
step "GitHub CLI (Linux)" bash scripts/gh-linux.sh
step "GitHub CLI (macOS)" bash scripts/gh-mac.sh
step "Tailscale tailnet join" bash scripts/tailscale-setup.sh
step "oh-my-zsh and plugins" install_oh_my_zsh
step "fzf" install_fzf
step "nvm and Node.js LTS" install_node
step "npm tools" install_npm_tools
step "curl-installed tools" install_curl_tools
step "wechat-reminder" install_wechat_reminder
step "bun, omp and omp plugins" install_omp
step "Herdr" install_herdr
step "Herdr app" bash scripts/install-herdr-app.sh
step "Neovim runtime pins and patches" bash scripts/neovim-runtime.sh
step "proxy-env unit" bash scripts/proxy-env-unit.sh
step "macOS defaults" bash scripts/macos-defaults.sh
step "15-minute sync scheduler" bash sync.sh --install

exit "$status"
