function docker-run --description "Create and run a Docker container"
    set -l volume_dir "$HOME/docker-volumes"
    if test (count $argv) -lt 2 -o (count $argv) -gt 3
        echo "Usage: docker-run <image name> <container name> [number of gpus (1|2|all)]"
        return 1
    end
    set -l image $argv[1]
    set -l container_name $argv[2]
    set -l mounted_home $volume_dir/$container_name
    mkdir -p $mounted_home
    if test (count $argv) -eq 2
        docker run -itd --restart=always --name $container_name --network host -e TERM=$TERM \
            -v $HOME:/host_data -v $mounted_home:/root -v /etc/localtime:/etc/localtime:ro \
            --privileged \
            $image /bin/bash
    else
        set -l gpus $argv[3]
        sudo docker run -itd --restart=always --name $container_name --network host -e TERM=$TERM \
            -v $HOME:/host_data -v $mounted_home:/root -v /etc/localtime:/etc/localtime:ro \
            --privileged \
            --gpus $gpus \
            $image /bin/bash
    end
end
