#!/bin/bash
# CC Gateway 安装脚本
# 用于 dotfiles 安装过程中自动配置 cc-gateway

set -e

CC_GATEWAY_DIR="$HOME/.cc-gateway"
REPO_URL="https://github.com/motiful/cc-gateway.git"

echo "=== Installing CC Gateway ==="

# 检查是否已安装
if [ -d "$CC_GATEWAY_DIR/.git" ]; then
    echo "CC Gateway already installed, updating..."
    cd "$CC_GATEWAY_DIR"
    git pull --quiet || true
else
    echo "Cloning CC Gateway repository..."
    rm -rf "$CC_GATEWAY_DIR"
    git clone --depth 1 "$REPO_URL" "$CC_GATEWAY_DIR"
fi

# 安装依赖并构建
cd "$CC_GATEWAY_DIR"
if [ -f "package.json" ]; then
    echo "Installing npm dependencies..."
    npm install --silent 2>/dev/null || npm install

    echo "Building CC Gateway..."
    npm run build
fi

# 检查是否已配置
if [ ! -f "$CC_GATEWAY_DIR/config.yaml" ]; then
    echo ""
    echo "=========================================="
    echo "CC Gateway 需要初始配置"
    echo "=========================================="
    echo ""
    echo "请手动运行以下命令完成配置："
    echo "  cd ~/.cc-gateway"
    echo "  bash scripts/quick-setup.sh"
    echo ""
    echo "这将："
    echo "  1. 从 macOS Keychain 提取 OAuth 凭证"
    echo "  2. 生成规范设备身份和客户端 token"
    echo "  3. 创建 config.yaml 配置文件"
    echo "  4. 生成客户端启动器"
    echo "  5. 启动网关服务"
    echo ""
    echo "配置完成后，使用 'ccg' 命令启动 Claude Code"
    echo ""
else
    echo "CC Gateway 已配置"

    # 查找客户端启动器
    CLIENT_LAUNCHER=$(find "$CC_GATEWAY_DIR/clients" -name "cc-*" -type f 2>/dev/null | head -1)

    if [ -n "$CLIENT_LAUNCHER" ]; then
        # 安装 ccg 命令
        mkdir -p "$HOME/.local/bin"
        ln -sf "$CLIENT_LAUNCHER" "$HOME/.local/bin/ccg"
        chmod +x "$CLIENT_LAUNCHER"
        echo "CC Gateway client linked to ~/.local/bin/ccg"
    fi

    echo "CC Gateway installed successfully. Use 'ccg' command to start."
fi

echo "=== CC Gateway installation complete ==="
