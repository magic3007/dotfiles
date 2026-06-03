# fzf
# Prepend ~/.fzf/bin to PATH so user-installed fzf takes priority over system fzf
[[ -d ~/.fzf/bin ]] && PATH="$HOME/.fzf/bin${PATH:+:${PATH}}"
[[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh
export FZF_DEFAULT_COMMAND="fd --type file --follow --hidden --no-ignore-vcs --exclude '.git' --exclude '[Mm]iniconda3' --exclude '[Aa]naconda3' --color=always"
export FZF_CTRL_T_COMMAND="${FZF_DEFAULT_COMMAND}"
FZF_PREVIEW_COMMAND="(bat --color=always {} || highlight -O ansi {} || cat {}) 2>/dev/null | head -100"
export FZF_DEFAULT_OPTS="--height=40% --layout=reverse --ansi --preview='${FZF_PREVIEW_COMMAND}'"
