#!/usr/bin/env bash

# proxy
# if directory not exist, create it
if [ ! -d $HOME/softwares ]; then
  mkdir $HOME/softwares
fi

cd ~/softwares
curl https://glados.rocks/tools/clash-linux.zip -o clash.zip
unzip clash.zip
cd clash
curl https://update.glados-config.com/clash/184231/4f45647/80139/glados-terminal.yaml > glados.yaml
chmod +x ./clash-linux-amd64-v1.10.0
tmux new-session -d -s "bk" ./clash-linux-amd64-v1.10.0 -f glados.yaml -d .
cd

echo "alias pc=http_proxy=http://127.0.0.1:7890 https_proxy=http://127.0.0.1:7890" >> ~/.bashrc
source ~/.bashrc

# mamba
pc wget https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
chmod u+x Miniforge3-Linux-x86_64.sh
./Miniforge3-Linux-x86_64.sh

# zsh
conda install -c conda-forge zsh

# oh-my-zsh
pc sh -c "$(pc curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# oh-my-zsh plugins
pc git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

# frp
cd ~/softwares
pc wget https://github.com/fatedier/frp/releases/download/v0.47.0/frp_0.47.0_linux_amd64.tar.gz
tar xzvf frp_0.47.0_linux_amd64.tar.gz
cd frp_0.47.0_linux_amd64

# set the server address and port in `frpc.ini` ...

./frpc -c ./frpc.ini
