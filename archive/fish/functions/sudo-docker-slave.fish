function sudo-docker-slave --description "Exec into a Docker container with sudo"
    if test (count $argv) -ne 1
        echo "Usage: sudo-docker-slave <container name>"
        return 1
    end
    sudo docker exec -it $argv[1] /bin/bash
end
