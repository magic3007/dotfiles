# Machine-local zsh overrides. This module sorts last, so ~/.zshrc_local can
# override every setting loaded before it, including the shared
# ~/.common_shell_setup_local.sh.
if [[ -f ~/.zshrc_local ]]; then
  typeset -gi DOTFILES_ZSHRC_LOCAL_LOAD_DEPTH=${DOTFILES_ZSHRC_LOCAL_LOAD_DEPTH:-0}
  if (( DOTFILES_ZSHRC_LOCAL_LOAD_DEPTH == 0 )); then
    (( DOTFILES_ZSHRC_LOCAL_LOAD_DEPTH++ ))
    source ~/.zshrc_local
    (( DOTFILES_ZSHRC_LOCAL_LOAD_DEPTH-- ))
  fi
fi
