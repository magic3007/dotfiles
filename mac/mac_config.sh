#!/usr/bin/env bash

defaults write NSGlobalDomain KeyRepeat -int 1 # Set blazingly fast key repeat rate.
defaults write NSGlobalDomain InitialKeyRepeat 12  # Set blazingly fast initial key repeat rate.

defaults write -g ApplePressAndHoldEnabled -bool false  # 关闭 Mac 长按字母键出现特殊字符（重音符号）菜单的功能

defaults write com.microsoft.VSCode ApplePressAndHoldEnabled -bool false              # For VS Code
defaults write com.microsoft.VSCodeInsiders ApplePressAndHoldEnabled -bool false      # For VS Code Insider
defaults write com.vscodium ApplePressAndHoldEnabled -bool false                      # For VS Codium
defaults write com.microsoft.VSCodeExploration ApplePressAndHoldEnabled -bool false   # For VS Codium Exploration users
defaults write com.exafunction.windsurf ApplePressAndHoldEnabled -bool false          # For Windsurf
defaults delete -g ApplePressAndHoldEnabled
