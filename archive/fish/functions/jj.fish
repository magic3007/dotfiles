function jj --description "joshuto with cd-on-exit"
    set -l output_file (mktemp)
    joshuto --output-file="$output_file" $argv
    set -l exit_code $status
    switch $exit_code
        case 101
            set -l joshuto_cwd (cat "$output_file")
            if test -n "$joshuto_cwd"; and test "$joshuto_cwd" != (pwd)
                cd "$joshuto_cwd"
            end
    end
    command rm -f "$output_file"
end
