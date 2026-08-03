# Dotbot 安装失败 - ~/.zshrc 符号链接创建失败

**日期**: 2026-03-30
**相关组件/模块**: Dotbot, 安装脚本, zsh配置
**状态**: 已解决

## 问题描述
运行 `./install` 安装 dotfiles 后，最终报告 "Some tasks were not executed successfully"，安装失败。需要诊断并修复问题。

## 症状与错误信息
1. 日志显示: `~/.zshrc already exists but is a regular file or directory`
2. 日志显示: `Some links were not successfully set up`
3. 最终总结: `==> Some tasks were not executed successfully`
4. 其他所有任务都执行成功，只有符号链接创建失败

## 根本原因分析
- `~/.zshrc` 已经作为常规文件存在于文件系统中
- Dotbot 无法在已存在的常规文件上创建符号链接
- 原安装脚本中的备份逻辑检测到 `~/.zshrc_bk` 已经存在，所以没有执行备份和移动操作，导致问题保留

## 解决方案
1. 手动备份现有的 `~/.zshrc` 文件（因为备份已经存在，使用不同后缀）
2. 删除或移动现有常规文件腾出位置
3. 创建符号链接指向 dotfiles 仓库中的目标文件
4. 重新运行安装程序确认全部成功

```bash
# 移动现有的zshrc（因为~/.zshrc_bk已经存在）
mv ~/.zshrc ~/.zshrc.current
# 创建符号链接
ln -s /Users/minimax/dotfiles/oh-my-zsh/zshrc ~/.zshrc
# 重新运行安装验证
./install
```

## 验证方法
1. 运行 `./install` 完成后显示 "==> All tasks executed successfully"
2. 检查符号链接: `ls -la ~/.zshrc` 确认指向正确路径
3. 验证关键组件都已正确安装:
   - oh-my-zsh 插件全部存在: `ls ~/.oh-my-zsh/custom/plugins/`
   - fzf 可执行: `command -v fzf`
   - 所有 AI CLI 工具都能找到: `claude`, `codex`, `gemini`, `opencode`, `wechat-reminder`

## 关键学习经验
1. Dotbot 不会自动覆盖已存在的常规文件，需要手动处理
2. 安装脚本中的备份逻辑只会在备份不存在时执行一次，如果重新安装，可能需要手动处理冲突
3. 即使单个符号链接失败，Dotbot 会继续执行其他任务，所以大多数组件都会正常安装，只需要修复失败的那一项

## 预防措施
1. 在运行 `./install` 之前，如果目标位置已经存在常规配置文件，应该手动备份
2. 可以修改安装脚本逻辑，即使备份存在也创建带时间戳的新备份，自动处理这种情况
3. 在 Dotbot 运行前添加一步检查，删除目标位置的常规文件（备份后）以允许符号链接创建

## 相关资源
- [install.conf.yaml](/Users/minimax/dotfiles/install.conf.yaml)
- [CLAUDE.md](/Users/minimax/dotfiles/CLAUDE.md)
- [Dotbot 官方文档](https://github.com/anishathalye/dotbot)
- [技能: dotbot-install-failure-diagnosis](/Users/minimax/.claude/skills/dotbot-install-failure-diagnosis)
