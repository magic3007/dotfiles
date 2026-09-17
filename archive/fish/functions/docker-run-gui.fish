function docker-run-gui --description "Create Docker container with X11 forwarding"
    set -l volume_dir "$HOME/docker-volumes"
    if test (count $argv) -lt 2 -o (count $argv) -gt 3
        echo "Usage: docker-run-gui <image name> <container name> [number of gpus (1|2|all)]"
        return 1
    end

    set -l image $argv[1]
    set -l container_name $argv[2]
    set -l mounted_home $volume_dir/$container_name
    mkdir -p $mounted_home

    # Setup X11 forwarding
    set -l XSOCK /tmp/.X11-unix
    set -l XAUTH /tmp/.docker.xauth
    xauth nlist $DISPLAY | sed -e 's/^..../ffff/' | xauth -f $XAUTH nmerge -
    chmod 777 $XAUTH

    if test (count $argv) -eq 2
        docker run -itd --restart=always --name $container_name --network host -e TERM=$TERM \
            -e DISPLAY=$DISPLAY \
            -e XAUTHORITY=$XAUTH \
            -v $HOME:/host_data -v $mounted_home:/root -v /etc/localtime:/etc/localtime:ro \
            -v $XSOCK:$XSOCK:ro \
            -v $XAUTH:$XAUTH:ro \
            --privileged \
            $image /bin/bash
    else
        set -l gpus $argv[3]
        sudo docker run -itd --restart=always --name $container_name --network host -e TERM=$TERM \
            -e DISPLAY=$DISPLAY \
            -e XAUTHORITY=$XAUTH \
            -v $HOME:/host_data -v $mounted_home:/root -v /etc/localtime:/etc/localtime:ro \
            -v $XSOCK:$XSOCK \
            -v $XAUTH:$XAUTH \
            --privileged \
            --gpus $gpus \
            $image /bin/bash
    end
end
