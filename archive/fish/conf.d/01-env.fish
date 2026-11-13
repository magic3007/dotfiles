# Environment variables

# Rust mirrors
set -gx RUSTUP_DIST_SERVER "https://rsproxy.cn"
set -gx RUSTUP_UPDATE_ROOT "https://rsproxy.cn/rustup"

# Hugo
set -gx HUGO_MODULE_PROXY "https://goproxy.cn/,direct"

# Editor
if command -q nvim
    set -gx EDITOR nvim
else
    set -gx EDITOR vim
end

# Julia
set -gx JULIA_PKG_SERVER "https://mirrors.tuna.tsinghua.edu.cn/julia"

# Flutter
set -gx PUB_HOSTED_URL "https://pub.flutter-io.cn"
set -gx FLUTTER_STORAGE_BASE_URL "https://storage.flutter-io.cn"

# uv - Python package manager
# No UV_INDEX_URL: it becomes uv's default index, and uv writes that index into every uv.lock it touches. See
# common_shell_setup.sh; use `uv --index-url <mirror>` for the one command that needs a mirror.

# Bun
set -gx BUN_INSTALL "$HOME/.bun"

# NVM
set -gx NVM_DIR "$HOME/.nvm"
