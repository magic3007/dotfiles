# Aliases and small helpers for the CLI tools installed on this machine.
alias dirs="dirs -v"
alias rsy="rsync -avzP"

# lsd - modern ls replacement
if command -v lsd &> /dev/null; then
  alias ls='lsd'
  alias la='lsd -la'
  alias ll='lsd -l'
  alias lt='lsd --tree'
fi

# cheat.sh
cheat(){
	curl cheat.sh/$1;
}

# ranger
rr() {
  ranger --choosedir="$HOME/.rangerdir"
  cd "$(cat "$HOME/.rangerdir")"
}

# joshuto
jj() {
  local output_file="$(mktemp)"
  joshuto --output-file="$output_file" "$@"
  local exit_code=$?
  case "$exit_code" in
    101)
      local joshuto_cwd="$(cat "$output_file")"
      [ -n "$joshuto_cwd" ] && [ "$joshuto_cwd" != "$(pwd)" ] && cd "$joshuto_cwd"
      ;;
  esac
  \rm -f "$output_file"
}

# yazi - exit to cwd
yy() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    builtin cd -- "$cwd"
  fi
  \rm -f -- "$tmp"
}

# Directory navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

# Colored grep on Linux
if command -v grep >/dev/null 2>&1; then
  if [[ $OS == "Linux" ]]; then
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
  fi
fi

# less with color support
if command -v less >/dev/null 2>&1; then
  export LESS='-R -F -X'
  # Colored man pages
  export LESS_TERMCAP_mb=$'\e[1;32m'
  export LESS_TERMCAP_md=$'\e[1;32m'
  export LESS_TERMCAP_me=$'\e[0m'
  export LESS_TERMCAP_se=$'\e[0m'
  export LESS_TERMCAP_so=$'\e[01;33m'
  export LESS_TERMCAP_ue=$'\e[0m'
  export LESS_TERMCAP_us=$'\e[1;4;31m'
fi

# lazygit
alias lg='lazygit'

# rg + fzf interactive search
rgf() {
  local pattern="${1:?Usage: rgf <pattern>}"
  rg -l "$pattern" | fzf --preview "rg -n --color=always -C 3 '$pattern' {}"
}

# zellij
alias zj="zellij"

# cursor
alias cs='cursor'

# lark-cli - Lark/Feishu CLI tool
alias lark='lark-cli'

# herdr terminal multiplexer
alias hd=herdr

# Tailscale - mesh VPN (tailnet)
# The macOS standalone/App Store app bundles the CLI; expose it when the
# "Install CLI" step has not created /usr/local/bin/tailscale. TAILSCALE_BE_CLI
# keeps the app bundle binary from opening a GUI window.
if ! command -v tailscale >/dev/null 2>&1; then
  for _ts_app in /Applications/Tailscale.app/Contents/MacOS/Tailscale \
                 "$HOME/Applications/Tailscale.app/Contents/MacOS/Tailscale"; do
    if [ -x "$_ts_app" ]; then
      # _ts_app stays set: the function reads it on every call.
      tailscale() { TAILSCALE_BE_CLI=1 "$_ts_app" "$@"; }
      break
    fi
  done
fi
if command -v tailscale >/dev/null 2>&1; then
  alias ts='tailscale'
  alias tss='tailscale status'
  # This node's Tailscale IPv4 address (empty when logged out/stopped).
  tsip() { tailscale ip -4 2>/dev/null | head -n 1; }
fi

# zoxide - smart cd
if command -v zoxide &> /dev/null; then
  if [ -n "$ZSH_VERSION" ]; then
    eval "$(zoxide init zsh)"
  elif [ -n "$BASH_VERSION" ]; then
    eval "$(zoxide init bash)"
  fi
fi

# starship - cross-shell prompt
if command -v starship &> /dev/null; then
  export STARSHIP_CONFIG=~/.config/starship.toml
  if [ -n "$ZSH_VERSION" ]; then
    eval "$(starship init zsh)"
  elif [ -n "$BASH_VERSION" ]; then
    eval "$(starship init bash)"
  fi
fi

# bat - cat with syntax highlighting
if command -v bat &> /dev/null; then
  alias cat='bat'
elif command -v batcat &> /dev/null; then
  alias cat='batcat'
  alias bat='batcat'
fi
