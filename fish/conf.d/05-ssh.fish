# SSH key auto-loading (interactive only)
status is-interactive; or return

if test -d $HOME/.ssh
    for possiblekey in $HOME/.ssh/id_*
        if test -f $possiblekey
            if command grep -q PRIVATE $possiblekey 2>/dev/null
                ssh-add $possiblekey 2>/dev/null
            end
        end
    end
end
