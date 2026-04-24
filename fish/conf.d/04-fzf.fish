# FZF configuration (interactive only)
status is-interactive; or return

set -gx FZF_DEFAULT_COMMAND "fd --type file --follow --hidden --no-ignore-vcs --exclude '.git' --exclude '[Mm]iniconda3' --exclude '[Aa]naconda3' --color=always"
set -gx FZF_CTRL_T_COMMAND $FZF_DEFAULT_COMMAND
set -gx FZF_DEFAULT_OPTS "--height=40% --layout=reverse --ansi --preview='(bat --color=always {} || highlight -O ansi {} || cat {}) 2>/dev/null | head -100'"
