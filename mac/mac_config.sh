#!/usr/bin/env bash

defaults write NSGlobalDomain KeyRepeat -int 1 # Set blazingly fast key repeat rate.
defaults write NSGlobalDomain InitialKeyRepeat 12  # Set blazingly fast initial key repeat rate.

defaults write -g ApplePressAndHoldEnabled -bool false  # 关闭 Mac 长按字母键出现特殊字符（重音符号）菜单的功能
