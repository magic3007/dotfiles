function rr --description "ranger with cd-on-exit"
    ranger --choosedir="$HOME/.rangerdir"
    cd (cat "$HOME/.rangerdir")
end
