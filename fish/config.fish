# Fish shell configuration
status is-interactive; or return

# Cargo
test -d $HOME/.cargo/bin; and fish_add_path $HOME/.cargo/bin

# Go proxy
if command -q go
    go env -w GO111MODULE=on
    go env -w GOPROXY=https://mirrors.aliyun.com/goproxy/,direct
end

# Conda initialization
set -l _conda_path $HOME/.miniforge3
if set -q CONDA_PATH
    set _conda_path $CONDA_PATH
end
if test -f $_conda_path/bin/conda
    eval ($_conda_path/bin/conda "shell.fish" "hook")
end
if test -f $_conda_path/etc/fish/conf.d/mamba.fish
    source $_conda_path/etc/fish/conf.d/mamba.fish
end

# Zoxide - smart cd
command -q zoxide; and zoxide init fish | source

# Starship prompt
if command -q starship
    set -gx STARSHIP_CONFIG ~/.config/starship.toml
    starship init fish | source
end

# Global Python venv
if test -d $HOME/.venv
    source $HOME/.venv/bin/activate.fish
end

# Antigravity
test -d $HOME/.antigravity/antigravity/bin; and fish_add_path $HOME/.antigravity/antigravity/bin
