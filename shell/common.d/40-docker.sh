# rootless docker helpers
# See NVIDIA CUDA container images at https://hub.docker.com/r/nvidia/cuda/tags
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
