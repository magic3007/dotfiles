#!/usr/bin/env bash
# macOS user defaults: fast key repeat everywhere, no press-and-hold accent menu
# (in VS Code-family editors too, so Vim keys repeat), and iTerm2 loading its
# preferences from the linked ~/.config/iterm2.
set -u

[ "$(uname)" = Darwin ] || exit 0

defaults write NSGlobalDomain KeyRepeat -int 1
defaults write NSGlobalDomain InitialKeyRepeat -int 12
defaults write -g ApplePressAndHoldEnabled -bool false

for app in com.microsoft.VSCode com.microsoft.VSCodeInsiders com.vscodium com.microsoft.VSCodeExploration; do
    defaults write "$app" ApplePressAndHoldEnabled -bool false
done

defaults write com.googlecode.iterm2.plist PrefsCustomFolder -string "$HOME/.config/iterm2"
defaults write com.googlecode.iterm2.plist LoadPrefsFromCustomFolder -bool true
