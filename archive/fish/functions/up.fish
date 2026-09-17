function up --description "Go up N directories"
    set -l n $argv[1]
    if test -z "$n"
        set n 1
    end
    if not string match -qr '^[0-9]+$' -- "$n"
        echo "usage: up [NUMBER]"
        return 1
    end
    set -l nwd (pwd)
    while test $n -gt 0
        set nwd (dirname $nwd)
        set n (math $n - 1)
    end
    cd $nwd
end
