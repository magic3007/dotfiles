# Platform name; the modules below branch on it.
OS=$(uname -s)

# Preferred editor for local work
if command -v nvim &> /dev/null; then
  export EDITOR='nvim'
else
  export EDITOR='vim'
fi

export COLORTERM=truecolor

# cargo / rustup
export RUSTUP_DIST_SERVER="https://rsproxy.cn"
export RUSTUP_UPDATE_ROOT="https://rsproxy.cn/rustup"
[ -f ~/.cargo/env ] && source ~/.cargo/env

# Language package mirrors
export HUGO_MODULE_PROXY=https://goproxy.cn/,direct
export JULIA_PKG_SERVER=https://mirrors.tuna.tsinghua.edu.cn/julia
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

# go writes these into its own config
if command -v go &> /dev/null; then
  go env -w GO111MODULE=on
  go env -w GOPROXY=https://mirrors.aliyun.com/goproxy/,direct
fi

# iTerm2 shell integration (macOS); absent elsewhere
test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

# uv installs to ~/.local/bin, already on PATH. No UV_INDEX_URL here,
# deliberately: it becomes uv's *default index*, and uv writes the index it
# resolved from into every lockfile it touches, so any project's uv.lock would
# carry this machine's mirror. Pass `--index-url` to the one command that needs
# a mirror instead. A machine-local value belongs in
# ~/.common_shell_setup_local.sh.

# Activate the global uv venv at ~/.venv
if [ -d "$HOME/.venv" ]; then
    source "$HOME/.venv/bin/activate"
fi
