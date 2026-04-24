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
set -gx UV_INDEX_URL "https://pypi.tuna.tsinghua.edu.cn/simple"

# Bun
set -gx BUN_INSTALL "$HOME/.bun"

# NVM
set -gx NVM_DIR "$HOME/.nvm"
