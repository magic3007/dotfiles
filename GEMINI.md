# Project: dotfiles

## Project Overview

This repository serves as a comprehensive collection of dotfiles and setup scripts designed to personalize and streamline the development environment across various operating systems (primarily Linux and macOS). It manages configurations for a wide array of command-line tools, editors, and system settings, ensuring a consistent and efficient user experience.

**Key Technologies/Tools Configured:**
*   **Shell:** Zsh (with Oh My Zsh and plugins like `zsh-syntax-highlighting`, `zsh-autosuggestions`, `autojump`, `zsh-vi-mode`).
*   **Terminal Multiplexers:** Tmux, Zellij.
*   **Editors:** Neovim (using `nvim-basic-ide` with Lua-based configuration), Vim, IdeaVim, VSCode.
*   **Version Control:** Git.
*   **Debugging:** GDB.
*   **Containerization:** Docker.
*   **Package Managers:** Conda, Mamba, npm, pip, Cargo (with CN mirrors configured).
*   **System Utilities:** Ranger (file manager), fzf (fuzzy finder), htop.
*   **macOS Specific:** Karabiner, yabai, skhd.
*   **AI Coding Tools:** Integrations/configurations for Claude, Codex, Gemini CLI, and custom shell functions for Deepseek and VolcEngine APIs.

**Architecture:**
The project leverages [Dotbot](https://github.com/anishathalye/dotbot) for automated and idempotent installation, primarily through symlinking configuration files to their respective locations in the home directory. System-level prerequisites, shell functions, aliases, and environment variables are managed via dedicated shell scripts (`install`, `common_shell_setup.sh`). Configurations for individual tools, especially Neovim, are modularized for clarity and maintainability.

## Building and Running

The dotfiles can be installed and set up by following these steps:

1.  **Clone the repository recursively:**
    ```bash
    git clone --recursive https://github.com/magic3007/dotfiles.git
    ```
2.  **Navigate into the cloned directory:**
    ```bash
    cd dotfiles
    ```
3.  **Run the installation script:**
    ```bash
    ./install
    ```

The `install` script, powered by Dotbot and configured via `install.conf.yaml`, performs the following actions:
*   Cleans up broken symlinks.
*   Creates essential directories (e.g., `~/.vim/undo-history`, `~/.wastebasket`, `~/.codex`, `~/.gemini`).
*   Clones various Git repositories for tools (e.g., `fzf`) and Oh My Zsh plugins.
*   Installs platform-specific system packages (e.g., `zsh`, `tmux`, `vim`, `htop`, `ranger` on Linux; `lazygit`, `zellij` on macOS).
*   Installs GitHub CLI (`gh`) and Node.js LTS via `nvm`.
*   Sets up post-clone plugins (e.g., `autojump`).
*   Backs up existing dotfiles before symlinking to prevent data loss.
*   Creates symlinks for all managed dotfiles from the repository to their target locations in the home directory.
*   Performs any remaining post-link setup (e.g., `fzf` installation).

## Development Conventions

*   **Installation Automation:** The project relies on `Dotbot` for automated symlinking and initial system setup, making the installation process repeatable and consistent.
*   **Local Customizations:** Users are encouraged to create local override files for specific configurations to avoid conflicts during updates. Examples include `~/.gitconfig_local` for Git, `~/.zsh_local` for Zsh, and `~/.common_shell_setup_local.sh` for additional shell settings.
*   **Modular Configuration:** Configuration for complex tools, such as Neovim, is broken down into smaller, logical Lua modules (e.g., `user.options`, `user.keymaps`, `user.plugins`) to enhance readability and maintainability.
*   **Shell Scripting:** The `common_shell_setup.sh` script is a central place for defining custom shell aliases (e.g., `dirs`, `els`, `rsy`), functions (e.g., `docker-run`, `cheat`), and setting crucial environment variables (e.g., `EDITOR`, `NVM_DIR`, and proxy settings for various language package managers). It also includes safety aliases for `rm`, `mv`, and `cp` to prevent accidental data loss.
