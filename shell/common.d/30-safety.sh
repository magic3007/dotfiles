# Guard the destructive commands: rm asks for a reversible delete, mv and cp
# prompt before overwriting.

# Helper: cross-shell read with prompt
# Usage: _shell_read prompt_text result_var
_shell_read() {
  if [ -n "$ZSH_VERSION" ]; then
    printf "%s" "$1"
    read -r "$2"
  else
    read -r -p "$1" "$2"
  fi
}

if [[ $OS == "Darwin" ]]; then
  # Modified from https://apple.stackexchange.com/questions/17622/how-can-i-make-rm-move-files-to-the-trash-can
  alias rm='echo -e "Use rem for reversible delete, \\\\rm for regular delete"'
  rem () {
    [ -n "$ZSH_VERSION" ] && setopt sh_word_split  # handle filenames with properly escaped spaces (zsh only)
    echo "Removing $*"
    _shell_read "OK?(y/n) " rem_resp
    if [[ ${rem_resp} == "y" ]]; then
      trash $*
    else
      echo "No action taken"
    fi
  }
elif [[ $OS == "Linux" ]]; then
  # Credit to https://web.physics.wustl.edu/alford/linux/precautions.html
  alias rm='echo -e "Use rem for reversible delete, \\\\rm for regular delete, wipe or srm for secure delete"'
  rem () {
    [ -n "$ZSH_VERSION" ] && setopt sh_word_split  # handle filenames with properly escaped spaces (zsh only)
    echo "Removing $*"
    _shell_read "OK?(y/n) " rem_resp
    if [[ ${rem_resp} == "y" ]]; then
      mv --backup=numbered -t ~/.wastebasket $*
    else
      echo "No action taken"
    fi
  }
fi

if [[ $OS == "Darwin" ]]; then
  alias mv='mv -i'
  alias cp='cp -i'
elif [[ $OS == "Linux" ]]; then
  alias mv='mv -i -b'
  alias cp='cp -i -b'
fi
