# History shared by bash and zsh: larger file, no duplicates, immediate append.
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoreboth:erasedups

if [ -n "$ZSH_VERSION" ]; then
  setopt INC_APPEND_HISTORY       # write to the history file immediately, not at shell exit
  setopt SHARE_HISTORY            # share history across concurrent sessions
  setopt HIST_IGNORE_DUPS         # don't record duplicate commands consecutively
  setopt HIST_IGNORE_SPACE        # don't record commands starting with space
  setopt HIST_REDUCE_BLANKS       # remove superfluous blanks from history
elif [ -n "$BASH_VERSION" ]; then
  shopt -s histappend             # append to the history file, don't overwrite
  # Prepend the immediate-save commands to an existing PROMPT_COMMAND if set
  if [ -z "$PROMPT_COMMAND" ]; then
    PROMPT_COMMAND="history -a; history -c; history -r"
  else
    PROMPT_COMMAND="history -a; history -c; history -r;${PROMPT_COMMAND}"
  fi
fi
