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

# iTerm2 shell integration
test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

# Golang Proxy
if command -v go &> /dev/null; then
  go env -w GO111MODULE=on
  go env -w GOPROXY=https://mirrors.aliyun.com/goproxy/,direct
fi

# julia
export JULIA_PKG_SERVER=https://mirrors.tuna.tsinghua.edu.cn/julia


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

# native claude code
cc() {
  claude --dangerously-skip-permissions "$@"
}

# cc-gateway claude code
ccg() {
  local ccg_bin
  ccg_bin=$(find "$HOME/.cc-gateway/clients" -maxdepth 1 -type f -name "cc-*" | head -n 1)
  if [[ -n "$ccg_bin" ]]; then
    "$ccg_bin" --dangerously-skip-permissions "$@"
  else
    echo "No ccg client found in $HOME/.cc-gateway/clients/" >&2
    return 1
  fi
}

# openai codex
cx() {
  codex --full-auto "$@"
}

# opencode
oc() {
  opencode "$@"
}
export PATH="$PATH:$HOME/.opencode/bin"

# google gemini cli (override oh-my-zsh git plugin's gm='git merge')
unalias gm 2>/dev/null
gm() {
  gemini --yolo "$@"
}

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
sdcc() {
  env -u ANTHROPIC_API_KEY \
    ANTHROPIC_BASE_URL=https://ark.cn-beijing.volces.com/api/coding \
    ANTHROPIC_AUTH_TOKEN="${VE_CODE_API_KEY}" \
    API_TIMEOUT_MS=600000 \
    ANTHROPIC_MODEL=doubao-seed-2.0-lite \
    ANTHROPIC_SMALL_FAST_MODEL=doubao-seed-2.0-lite \
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
    claude "$@" --dangerously-skip-permissions
}

sdccmini() {
  env -u ANTHROPIC_API_KEY \
    ANTHROPIC_BASE_URL=https://ark.cn-beijing.volces.com/api/compatible \
    ANTHROPIC_AUTH_TOKEN="${SD2MINI_API_KEY}" \
    API_TIMEOUT_MS=600000 \
    ANTHROPIC_MODEL=doubao-seed-2-0-mini-260215 \
    ANTHROPIC_SMALL_FAST_MODEL=doubao-seed-2-0-mini-260215 \
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
    claude "$@" --dangerously-skip-permissions
}

sdccpro() {
  env -u ANTHROPIC_API_KEY \
    ANTHROPIC_BASE_URL=https://ark.cn-beijing.volces.com/api/coding \
    ANTHROPIC_AUTH_TOKEN="${VE_CODE_API_KEY}" \
    API_TIMEOUT_MS=600000 \
    ANTHROPIC_MODEL=doubao-seed-2.0-pro \
    ANTHROPIC_SMALL_FAST_MODEL=doubao-seed-2.0-pro \
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
    claude "$@" --dangerously-skip-permissions
}

kmcc() {
  env -u ANTHROPIC_API_KEY \
    ANTHROPIC_BASE_URL=https://api.kimi.com/coding/ \
    ANTHROPIC_AUTH_TOKEN="${KIMI_CODE_API_KEY}" \
    API_TIMEOUT_MS=600000 \
    ANTHROPIC_MODEL=kimi-for-coding \
    ANTHROPIC_SMALL_FAST_MODEL=kimi-for-coding \
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
    claude "$@" --dangerously-skip-permissions
}

kmcc2() {
  env -u ANTHROPIC_API_KEY \
    ANTHROPIC_BASE_URL=https://api.moonshot.cn/anthropic \
    ANTHROPIC_AUTH_TOKEN="${KIMI_API_KEY}" \
    API_TIMEOUT_MS=600000 \
    ANTHROPIC_MODEL=kimi-k2.5 \
    ANTHROPIC_SMALL_FAST_MODEL=kimi-k2.5 \
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
    claude "$@" --dangerously-skip-permissions
}

# claude code with MiniMax 2.7
mxcc() {
  env -u ANTHROPIC_API_KEY \
    ANTHROPIC_BASE_URL=https://openrouter.ai/api \
    ANTHROPIC_AUTH_TOKEN="${OPENROUTER_API_KEY}" \
    API_TIMEOUT_MS=600000 \
    ANTHROPIC_MODEL=minimax/minimax-m2.7 \
    ANTHROPIC_SMALL_FAST_MODEL=minimax/minimax-m2.7 \
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
    claude "$@" --dangerously-skip-permissions
}

# claude code with mimo-v2-pro
mmcc() {
  env -u ANTHROPIC_API_KEY \
    ANTHROPIC_BASE_URL=https://token-plan-cn.xiaomimimo.com/anthropic\
    ANTHROPIC_AUTH_TOKEN="${MIMO_CODE_API_KEY}" \
    API_TIMEOUT_MS=600000 \
    ANTHROPIC_MODEL=mimo-v2-pro \
    ANTHROPIC_SMALL_FAST_MODEL=mimo-v2-pro \
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
    claude "$@" --dangerously-skip-permissions
}

# claude code with mimo-v2-pro
mmcc2() {
  env -u ANTHROPIC_API_KEY \
    ANTHROPIC_BASE_URL=https://api.xiaomimimo.com/anthropic \
    ANTHROPIC_AUTH_TOKEN="${MIMO_API_KEY}" \
    API_TIMEOUT_MS=600000 \
    ANTHROPIC_MODEL=mimo-v2-pro \
    ANTHROPIC_SMALL_FAST_MODEL=mimo-v2-pro \
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
    claude "$@" --dangerously-skip-permissions
}

remind() {
  ssh -t pkucpu "export FEISHU_WEBHOOK_URL=$FEISHU_WEBHOOK_URL; ~/.local/bin/wechat-reminder --title $HOSTNAME"
}

# uv - Python package manager
# uv installs to ~/.local/bin by default
export PATH="$HOME/.local/bin:$PATH"

# uv Python mirror for China
export UV_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple

# Activate global uv venv at ~/.venv
if [ -d "$HOME/.venv" ]; then
    source "$HOME/.venv/bin/activate"
fi

# codex environment setup
[ -f ~/.codex/codex_env.sh ] && source ~/.codex/codex_env.sh

[ -f ~/.common_shell_setup_local.sh ] && source ~/.common_shell_setup_local.sh


# Added by Antigravity
[ -f ~/.antigravity/antigravity/bin/antigravity ] && export PATH="$PATH:$HOME/.antigravity/antigravity/bin"
