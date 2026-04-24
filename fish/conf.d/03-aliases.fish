# Aliases (interactive only)
status is-interactive; or return

# General
alias rsy 'rsync -avzP'

# lsd - modern ls replacement
if command -q lsd
    alias ls lsd
    alias la 'lsd -la'
    alias ll 'lsd -l'
    alias lt 'lsd --tree'
    alias els 'lsd -l'
else
    alias els 'exa -l'
end

# lazygit
alias lg lazygit

# zellij
alias zj zellij

# cursor
alias cs cursor

# Safe rm override (use `command rm` to bypass in fish)
if test (uname -s) = Darwin
    function rm --description "Safe rm reminder"
        echo "Use rem for reversible delete, command rm for regular delete"
    end
    alias mv 'mv -i'
    alias cp 'cp -i'
else if test (uname -s) = Linux
    function rm --description "Safe rm reminder"
        echo "Use rem for reversible delete, command rm for regular delete, wipe or srm for secure delete"
    end
    alias mv 'mv -i -b'
    alias cp 'cp -i -b'
end

# bat - cat with syntax highlighting
if command -q bat
    alias cat bat
else if command -q batcat
    alias cat batcat
    alias bat batcat
end
