# zsh 启动无限递归导致 shell 挂起

**日期**: 2026-04-04
**相关组件/模块**: zsh, oh-my-zsh, dotfiles
**状态**: 已解决

## 问题描述
zsh 启动特别慢，`zsh -i -c exit` 超过 30 秒未完成，shell 完全挂起。

## 症状与错误信息
- zsh 启动后无响应，无法进入 shell prompt
- 大量 `(eval):1: can't change option: zle` 警告（oh-my-zsh 被重复加载的副作用）
- 超过 30 秒后仍未完成启动

## 根本原因分析
`~/.zshrc_local` 文件是主 `~/.zshrc`（即 `oh-my-zsh/zshrc`）的完整拷贝（354 行 vs 355 行），而不是仅包含本地自定义内容。

启动流程变成无限递归：
1. `~/.zshrc` 加载 oh-my-zsh + 所有插件
2. `~/.zshrc` 执行 `source ~/.zshrc_local`
3. `~/.zshrc_local`（内容几乎相同）再次加载 oh-my-zsh + 所有插件
4. `~/.zshrc_local` 再次执行 `source ~/.zshrc_local`
5. 无限循环 → shell 挂起

另外发现 `~/.zshrc` 本身也不是符号链接而是普通文件（被 root 覆盖），可能是系统更新或其他工具覆盖了 dotbot 创建的符号链接。

## 解决方案
1. 备份原文件：`~/.zshrc_local.bak` 和 `~/.zshrc.bak`
2. 将 `~/.zshrc_local` 替换为仅包含本地自定义内容（`setopt SHARE_HISTORY`）
3. 重建 `~/.zshrc` 符号链接指向 `dotfiles/oh-my-zsh/zshrc`

## 验证方法
```bash
time zsh -i -c exit
```
修复前：>30 秒挂起；修复后：0.71 秒。

## 关键学习经验
1. `*_local` 文件应该只包含本地自定义内容，绝不应该是主配置文件的拷贝
2. 当 shell 启动挂起时，首先检查是否有递归 source 的情况
3. 检查关键 dotfiles（如 `~/.zshrc`）是否仍然是符号链接，系统更新可能会覆盖它们

## 预防措施
1. 定期运行 `./install -n`（dry run）检查符号链接状态
2. `~/.zshrc_local` 开头加注释说明其用途，避免误将主 zshrc 内容粘贴进去
3. 考虑在 `oh-my-zsh/zshrc` 中添加递归保护（如设置环境变量标记已加载）

## 相关资源
- `oh-my-zsh/zshrc` — 主 zsh 配置
- `install.conf.yaml` — dotbot 安装配置
- `~/.zshrc_local` — 本地 zsh 自定义（不纳入 git）
