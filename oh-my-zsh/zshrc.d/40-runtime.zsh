# common shell setup for bash and zsh
[[ -f ~/.common_shell_setup.sh ]] && source ~/.common_shell_setup.sh

# local customizations in ~/.zshrc_local
if [[ -f ~/.zshrc_local ]]; then
  typeset -gi DOTFILES_ZSHRC_LOCAL_LOAD_DEPTH=${DOTFILES_ZSHRC_LOCAL_LOAD_DEPTH:-0}
  if (( DOTFILES_ZSHRC_LOCAL_LOAD_DEPTH == 0 )); then
    (( DOTFILES_ZSHRC_LOCAL_LOAD_DEPTH++ ))
    source ~/.zshrc_local
    (( DOTFILES_ZSHRC_LOCAL_LOAD_DEPTH-- ))
  fi
fi

# avoid duplicate PATH entries
typeset -U path PATH
path=($path)

# Lazy-load nvm only when needed.
export NVM_DIR="$HOME/.nvm"
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  nvm() {
    unfunction nvm 2>/dev/null
    source "$NVM_DIR/nvm.sh"
    [[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"
    nvm "$@"
  }
fi

# bun completions
[[ -s "$HOME/.bun/_bun" ]] && source "$HOME/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
path=("$BUN_INSTALL/bin" $path)

# Share history across multiple shell sessions
setopt SHARE_HISTORY

# opencode
path=("$HOME/.opencode/bin" $path)

[[ -s "$HOME/.local/bin/env" ]] && source "$HOME/.local/bin/env"
