# useful alias
alias dirs="dirs -v"
alias els="exa -l"
alias rsy="rsync -avzP"

# proxy
# function pc() {
# 	https_proxy=http://127.0.0.1:7890 \
# 	http_proxy=http://127.0.0.1:7890  \
#   all_proxy=socks5://127.0.0.1:7891 \
# 	"$@"
# }
# alias pc="https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7891"

# The fuck
# command -v thefuck >/dev/null 2>&1 && eval $(thefuck --alias)

# cargo
export RUSTUP_DIST_SERVER="https://rsproxy.cn"
export RUSTUP_UPDATE_ROOT="https://rsproxy.cn/rustup"
[ -f ~/.cargo/env ] && source ~/.cargo/env

# hugo Proxy
export HUGO_MODULE_PROXY=https://goproxy.cn/,direct


# Preferred editor for local
if command -v nvim &> /dev/null; then
  export EDITOR='nvim'
else
  export EDITOR='vim'
fi

# cheat.sh
cheat(){
	curl cheat.sh/$1;
}

# ranger
alias ra='ranger --choosedir=$HOME/.rangerdir; LASTDIR=`cat $HOME/.rangerdir`; cd "$LASTDIR"'

# iTerm2 shell integration
test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

# Golang Proxy
if command -v go &> /dev/null; then
  go env -w GO111MODULE=on
  go env -w GOPROXY=https://mirrors.aliyun.com/goproxy/,direct
fi

# julia
export JULIA_PKG_SERVER=https://mirrors.tuna.tsinghua.edu.cn/julia

# nvm: manager for multiple versions of node.js
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# docker
# rootless docker
# Reference
# - See NVIDIA CUDA container from https://hub.docker.com/r/nvidia/cuda/tags
docker-run(){
  local volume_dir="$HOME/docker-volumes"
  if [ $# -ne 2 ] && [ $# -ne 3 ]; then
    echo "No Arguments specified.\nUsage:\n docker-run <image name> <container name> [number of gpus (1|2|all)]\n">&2;
    return 1;
  fi;
  local container_name=$2
  local mounted_home=$volume_dir/$container_name
  mkdir -p $mounted_home
  if [ $# -eq 2 ]; then
    set -x
    docker run -itd --restart=always --name $2 --network host -e TERM=$TERM \
      -v $HOME:/host_data -v $mounted_home:/root -v /etc/localtime:/etc/localtime:ro \
      --privileged \
      $1 /bin/bash;
    set +x
  else
    local gpus=$3
    set -x
    sudo docker run -itd --restart=always --name $2 --network host -e TERM=$TERM \
      -v $HOME:/host_data -v $mounted_home:/root -v /etc/localtime:/etc/localtime:ro \
      --privileged \
      --gpus $gpus \
      $1 /bin/bash;
    set +x
  fi;
}

docker-slave(){
  if [ $# -ne 1 ]; then
      echo "No Arguments specified.\nUsage:\n docker-slave <container name>\n">&2;
      return 1;
  fi;
  docker exec -it $1 /bin/bash;
}

sudo-docker-slave(){
  if [ $# -ne 1 ]; then
      echo "No Arguments specified.\nUsage:\n docker-slave <container name>\n">&2;
      return 1;
  fi;
  sudo docker exec -it $1 /bin/bash;
}

# Make mv and cp safer
OS=$(uname -s)

if [[ $OS == "Darwin" ]]; then
  # Modified from https://apple.stackexchange.com/questions/17622/how-can-i-make-rm-move-files-to-the-trash-can
  # - Correcting bad habits
  alias rm='echo -e "Use rem for reversible delete, \\\\rm for regular delete"'
  rem () {
    setopt sh_word_split  # handle filenames with properly escaped spaces
    echo "Removing $*"
    read "rem_resp?OK?(y/n) "
    if [[ ${rem_resp} == "y" ]]; then
      trash $*
    else
      echo "No action taken"
    fi
  }
elif [[ $OS == "Linux" ]]; then
  # Use a safe deletion command instead of rm
  # Credit to https://web.physics.wustl.edu/alford/linux/precautions.html
  alias rm='echo -e "Use rem for reversible delete, \\\\rm for regular delete, wipe or srm for secure delete"'
  rem () {
    setopt sh_word_split  # handle filenames with properly escaped spaces
    echo "Removing $*"
    read "rem_resp?OK?(y/n) "
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


# vscode
[ -f ~/.vscoderc ] && source ~/.vscoderc

# setup path
export PATH=$HOME/.local/bin:$PATH

# add all private keys to ssh agent
if find "${HOME}/.ssh" -name "id_*" -print -quit | grep -q .; then
    for possiblekey in ${HOME}/.ssh/id_*; do
        if grep -q PRIVATE "$possiblekey" 2>/dev/null; then
            ssh-add "$possiblekey" 2>/dev/null
        fi
    done
fi


export PATH="/opt/homebrew/opt/ruby/bin:$PATH"

# chatgpt.sh
export PATH="$PATH:$HOME/.chatgpt"

# lazygit
alias lg='lazygit'

# zellij
alias zj="zellij"
