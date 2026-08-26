# omp (Stencil / oh-my-pi) — dotfiles 配置

`omp` 是一个 **AI coding agent harness**（不是提示符主题工具！不要和 Oh My Posh 混淆）。

- 官网: https://omp.sh
- npm/bun 包: `@oh-my-pi/pi-coding-agent`
- 安装: `curl -fsSL https://omp.sh/install | sh`（装到 `~/.bun/bin/omp`）

## 软链接

`install.conf.yaml` 只软链接了**一个静态配置**：

    ~/.omp/agent/config.yml  ->  omp/config.yml

该目录下其余内容（`agent.db`、`history.db`、`models.db`、`sessions/`、
`cache/`、`terminal-sessions/`）是**运行时状态**，各机器不同，留在本机、不进 git。

## 关于 config.yml 的三条硬性约束

1. **必须可写**。omp 会对 config.yml 上 native file lock，只读符号链接或只读 store
   文件会导致每次启动报 `Failed to acquire native file lock … Permission denied`。
   repo 里的 `omp/config.yml` 保持普通可写文件即可（omp 的原子写会保留 symlink target）。

2. **不支持注释**。`omp config set/reset` 重写文件时会剥离注释。所以本文件保持
   **纯 YAML 数据**，说明性文字请放在本 README 或 AGENTS.md，不要写进 config.yml。

3. **不要存密钥**。`auth.*` / provider token / broker 凭据等敏感信息**绝不入库**，
   用环境变量或私有 overlay（`omp --config ~/.omp/private.yml`）。

## 常用命令

    omp config list                  # 查看所有 key + 当前/默认值
    omp config set   <key> <value>   # 设置并持久化到 config.yml（写透 symlink）
    omp config get   <key>           # 读取
    omp config reset <key>           # 恢复默认
    omp config path                  # 打印 agent 配置目录 (~/.omp/agent)

Key 是**扁平**格式：`omp config set theme.dark titanium` 对应嵌套
`theme: { dark: titanium }`。只写入被覆盖的 key，其余 deep-merge 默认值。

## 可选：纳入更多静态配置

若想跟踪 agents / skills / hooks，可用 `omp agents unpack`（默认写到
`~/.omp/agent/agents`）后软链接对应子目录。当前按需再补。
