function rem --description "Reversible delete (trash on macOS, wastebasket on Linux)"
    if test (count $argv) -eq 0
        echo "Usage: rem <file>..."
        return 1
    end
    echo "Removing $argv"
    read -P "OK?(y/n) " rem_resp
    if test "$rem_resp" = y
        if test (uname -s) = Darwin
            trash $argv
        else
            mv --backup=numbered -t ~/.wastebasket $argv
        end
    else
        echo "No action taken"
    end
end
