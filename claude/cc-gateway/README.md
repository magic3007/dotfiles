# CC Gateway 配置

CC Gateway 是 Claude Code 的反向代理，用于规范化设备指纹和遥测数据。

## 用途

- 重写设备 ID、邮箱、环境对象等身份标识
- 剥离 `x-anthropic-billing-header` 计费头
- 集中管理 OAuth，客户端无需登录

## 安装流程

安装脚本 (`~/.claude/cc-gateway/install.sh`) 会自动：
1. 克隆 cc-gateway 仓库到 `~/.cc-gateway`
2. 安装 npm 依赖并构建项目
3. 如果尚未配置，提示运行 `quick-setup.sh`

### 初始配置（必需）

首次安装后需要手动运行配置：

```bash
cd ~/.cc-gateway
bash scripts/quick-setup.sh
```

这会：
1. 从 macOS Keychain 提取 OAuth 凭证
2. 生成规范设备身份和客户端 token
3. 创建 `config.yaml` 配置文件
4. 在 `~/.cc-gateway/clients/` 生成客户端启动器
5. 启动网关服务

## 使用方法

配置完成后：

```bash
# 通过网关启动 Claude Code
ccg

# 安装 ccg 为系统命令（客户端启动器自带功能）
ccg install

# 让 claude 命令也走网关
ccg hijack

# 恢复原生 claude 命令
ccg release

# 查看状态
ccg status
```

## 环境变量

cc-gateway 会自动处理：
- `ANTHROPIC_BASE_URL` - 指向网关地址
- `CLAUDE_CODE_ATTRIBUTION_HEADER=false` - 禁用计费头

## 文件位置

- 仓库: `~/.cc-gateway`
- 配置: `~/.cc-gateway/config.yaml`
- 客户端启动器: `~/.cc-gateway/clients/cc-<hostname>`
- 命令链接: `~/.local/bin/ccg`

## 参考

- 上游仓库: https://github.com/motiful/cc-gateway
