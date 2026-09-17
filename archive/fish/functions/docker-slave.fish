function docker-slave --description "Exec into a Docker container"
    if test (count $argv) -ne 1
        echo "Usage: docker-slave <container name>"
        return 1
    end
    docker exec -it $argv[1] /bin/bash
end
