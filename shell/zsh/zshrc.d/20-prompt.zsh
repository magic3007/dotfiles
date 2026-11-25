# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# Elapsed and execution time display for commands in ZSH
# https://gist.github.com/knadh/123bca5cfdae8645db750bfb49cb44b0
autoload -Uz add-zsh-hook

_dotfiles_preexec_timer() {
  DOTFILES_TIMER_MS=$(($(print -P %D{%s%6.})/1000))
}

_dotfiles_precmd_timer() {
  # restore cursor visibility (fixes invisible cursor after unexpected SSH disconnect)
  printf '\e[?25h'
  # add a newline after each command
  print ""
  if [[ -n "${DOTFILES_TIMER_MS:-}" ]]; then
    local now d_ms d_s ms s m h
    now=$(($(print -P %D{%s%6.})/1000))
    d_ms=$((now-DOTFILES_TIMER_MS))
    d_s=$((d_ms / 1000))
    ms=$((d_ms % 1000))
    s=$((d_s % 60))
    m=$(((d_s / 60) % 60))
    h=$((d_s / 3600))
    if ((h > 0)); then DOTFILES_ELAPSED=${h}h${m}m
    elif ((m > 0)); then DOTFILES_ELAPSED=${m}m${s}s
    elif ((s >= 10)); then DOTFILES_ELAPSED=${s}.$((ms / 100))s
    elif ((s > 0)); then DOTFILES_ELAPSED=${s}.$((ms / 10))s
    else DOTFILES_ELAPSED=${ms}ms
    fi

    unset DOTFILES_TIMER_MS
  else
    unset DOTFILES_ELAPSED
  fi
}

add-zsh-hook preexec _dotfiles_preexec_timer
add-zsh-hook precmd _dotfiles_precmd_timer

setopt PROMPT_SUBST
RPROMPT='%F{cyan}${DOTFILES_ELAPSED:+${DOTFILES_ELAPSED} }%D{%m-%d %T}%f'
