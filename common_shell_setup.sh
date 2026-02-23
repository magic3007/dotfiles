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
alias rr='ranger --choosedir=$HOME/.rangerdir; LASTDIR=`cat $HOME/.rangerdir`; cd "$LASTDIR"'

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

# docker with X11 forwarding support
# Reference: setup-gui-docker.md
docker-run-gui(){
  local volume_dir="$HOME/docker-volumes"
  if [ $# -ne 2 ] && [ $# -ne 3 ]; then
    echo "No Arguments specified.\nUsage:\n docker-run-gui <image name> <container name> [number of gpus (1|2|all)]\n">&2;
    return 1;
  fi;

  local container_name=$2
  local mounted_home=$volume_dir/$container_name
  mkdir -p $mounted_home

  # Setup X11 forwarding
  local XSOCK=/tmp/.X11-unix
  local XAUTH=/tmp/.docker.xauth
  xauth nlist $DISPLAY | sed -e 's/^..../ffff/' | xauth -f $XAUTH nmerge -
  chmod 777 $XAUTH

  if [ $# -eq 2 ]; then
    set -x
    docker run -itd --restart=always --name $2 --network host -e TERM=$TERM \
      -e DISPLAY=$DISPLAY \
      -e XAUTHORITY=$XAUTH \
      -v $HOME:/host_data -v $mounted_home:/root -v /etc/localtime:/etc/localtime:ro \
      -v $XSOCK:$XSOCK:ro \
      -v $XAUTH:$XAUTH:ro \
      --privileged \
      $1 /bin/bash;
    set +x
  else
    local gpus=$3
    set -x
    sudo docker run -itd --restart=always --name $2 --network host -e TERM=$TERM \
      -e DISPLAY=$DISPLAY \
      -e XAUTHORITY=$XAUTH \
      -v $HOME:/host_data -v $mounted_home:/root -v /etc/localtime:/etc/localtime:ro \
      -v $XSOCK:$XSOCK \
      -v $XAUTH:$XAUTH \
      --privileged \
      --gpus $gpus \
      $1 /bin/bash;
    set +x
  fi;
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

# flutter
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

# cursor
alias cs='cursor'

# claude code
alias cc='claude --dangerously-skip-permissions'

# openai codex
alias cx='codex'

# google gemini cli (override oh-my-zsh git plugin's gm='git merge')
unalias gm 2>/dev/null; alias gm='gemini'

# claude code with deepseek API
# Reference: https://api-docs.deepseek.com/guides/anthropic_api
dscc() {
  env -u ANTHROPIC_API_KEY \
    ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic \
    ANTHROPIC_AUTH_TOKEN="${DEEPSEEK_API_KEY}" \
    API_TIMEOUT_MS=600000 \
    ANTHROPIC_MODEL=deepseek-chat \
    ANTHROPIC_SMALL_FAST_MODEL=deepseek-chat \
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
    claude "$@" --dangerously-skip-permissions
}


# claude code with VolcEngine Coding Plan
# Reference: https://www.volcengine.com/docs/82379/1928262?lang=zh
kmcc() {
  env -u ANTHROPIC_API_KEY \
    ANTHROPIC_BASE_URL=https://ark.cn-beijing.volces.com/api/coding \
    ANTHROPIC_AUTH_TOKEN="${VE_API_KEY}" \
    API_TIMEOUT_MS=600000 \
    ANTHROPIC_MODEL=kimi-k2.5 \
    ANTHROPIC_SMALL_FAST_MODEL=kimi-k2.5 \
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
    claude "$@" --dangerously-skip-permissions
}

# claude code with MiniMax 2.5
mxcc() {
  env -u ANTHROPIC_API_KEY \
    ANTHROPIC_BASE_URL=https://openrouter.ai/api \
    ANTHROPIC_AUTH_TOKEN="${OPENROUTER_API_KEY}" \
    API_TIMEOUT_MS=600000 \
    ANTHROPIC_MODEL=minimax/minimax-m2.5 \
    ANTHROPIC_SMALL_FAST_MODEL=minimax/minimax-m2.5 \
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
    claude "$@" --dangerously-skip-permissions
}

alias remind="ssh -t pkucpu \"export FEISHU_WEBHOOK_URL=\$FEISHU_WEBHOOK_URL; ~/.local/bin/wechat-reminder --title \$HOSTNAME\""

# codex environment setup
[ -f ~/.codex/codex_env.sh ] && source ~/.codex/codex_env.sh

[ -f ~/.common_shell_setup_local.sh ] && source ~/.common_shell_setup_local.sh


# Added by Antigravity
[ -f ~/.antigravity/antigravity/bin/antigravity ] && export PATH="$PATH:$HOME/.antigravity/antigravity/bin"
