# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a dotfiles repository containing configuration files for development tools and environments. It uses [Dotbot](https://github.com/anishathalye/dotbot) for installation and management.

## Installation and Setup

The primary command to set up the development environment is:

```bash
./install
```

This script:
1. Installs prerequisites (zsh, tmux, vim, etc.) based on the operating system
2. Sets up oh-my-zsh with plugins
3. Installs AI coding tools (Claude Code CLI, OpenAI Codex)
4. Creates symlinks from repository files to appropriate locations in `~`

The installation is idempotent and can be run multiple times safely.

## Repository Structure

### Core Configuration Directories
- `oh-my-zsh/` - Zsh configuration and oh-my-zsh setup
- `vim/vimrc/` - Vim configuration with plugin management
- `neovim/` - Neovim configuration (including NvChad-based setup)
- `git/` - Git configuration with local customization support
- `cursor_config/` - Cursor editor settings and keybindings
- `claude/` - Claude Code CLI configuration
- `bash/` - Bash shell configuration
- `ranger/` - Ranger file manager configuration
- `skhd/` - macOS window management shortcuts
- `karabiner/` - macOS keyboard remapping

### Tool-Specific Configurations
- `docker/` - Docker setup and configuration
- `gdb/` - GDB debugger configuration
- `tmux.conf` - Terminal multiplexer configuration
- `ideavimrc` - IntelliJ IDEA Vim emulation
- Package manager configs: `.condarc`, `.mambarc`, `.npmrc`, `pip.conf`, `cargo/config.toml`

### Scripts and Utilities
- `scripts/` - Utility scripts (backup, mounting, setup)
- `common_shell_setup.sh` - Shared shell configuration sourced by both bash and zsh
- `install.conf.yaml` - Dotbot configuration defining installation steps

## Key Architecture Concepts

### Symlink-Based Configuration
Configuration files are stored in the repository and symlinked to their standard locations:
- Shell configs: `~/.zshrc`, `~/.bashrc`
- Editor configs: `~/.vimrc`, `~/.config/nvim`, `~/.ideavimrc`
- Git: `~/.gitconfig`
- Other tools: `~/.tmux.conf`, `~/.config/ranger`, etc.

### Local Customizations
Users can create local customizations that won't be overwritten:
- `~/.gitconfig_local` - Local Git configuration
- `~/.zsh_local` - Local Zsh configuration
- `~/.common_shell_setup_local.sh` - Local shell setup

### AI Tool Integration
The repository includes configuration for:
- **Claude Code CLI**: Configured in `claude/settings.json` with Chinese language setting
- **OpenAI Codex**: Shell alias setup in `common_shell_setup.sh`
- **DeepSeek API**: Integration via environment variables and shell function `dscc()`

### Cross-Platform Support
The installation script detects the operating system and installs appropriate packages:
- **Linux**: Uses apt-get for zsh, tmux, vim, htop, ranger
- **macOS**: Uses Homebrew for lazygit, zellij

### Proxy and Mirror Configuration
Chinese mirrors are configured for faster package downloads:
- Rust: rsproxy.cn
- Go: mirrors.aliyun.com
- npm: Custom registry in `.npmrc`
- pip: Chinese mirror in `pip.conf`
- Conda/Mamba: Configuration in `.condarc` and `.mambarc`

## Development Workflow

### Adding New Configuration
1. Add configuration files to the appropriate directory in the repository
2. Update `install.conf.yaml` to add symlinks or installation steps
3. Test with `./install` (dry run available with `-n` flag)

### Updating Existing Configuration
1. Modify files in the repository
2. Run `./install` to update symlinks
3. Local customizations in `*_local` files are preserved

### Plugin Management
- Vim plugins are managed via git submodules in `vim/vimrc/sources_*`
- oh-my-zsh plugins are cloned during installation
- Neovim uses NvChad-based configuration

## Common Commands

```bash
# Full installation
./install

# Dry run (see what would be installed)
./install -n

# Update submodules (plugins)
git submodule update --init --recursive

# Install specific components (see install.conf.yaml for phases)
./install --plugin-dir dotbot-git --only git
```

## Notes for Claude Code

- This repository focuses on configuration files, not application code
- Changes should maintain cross-platform compatibility
- Sensitive information should be placed in `*_local` files (excluded from git)
- The `claude/settings.json` is already configured for Chinese language output
- Shell integration includes fzf, autojump, and syntax highlighting
- Editor configurations follow consistent formatting rules across languages