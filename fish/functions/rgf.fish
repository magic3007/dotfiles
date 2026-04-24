function rgf --description "rg + fzf interactive search"
    if test (count $argv) -eq 0
        echo "Usage: rgf <pattern>"
        return 1
    end
    set -l pattern $argv[1]
    rg -l "$pattern" | fzf --preview "rg -n --color=always -C 3 '$pattern' {}"
end
