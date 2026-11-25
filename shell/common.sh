# Shared settings for bash and zsh. The modules in common.d run in file-name
# order; ~/.common_shell_setup_local.sh runs last, so it overrides any of them.
#
# This file is reached through the ~/.common_shell_setup.sh symlink, so resolve
# that link to find common.d next to the real file — no checkout path here.
_dotfiles_src=${BASH_SOURCE[0]:-$0}
while [ -L "$_dotfiles_src" ]; do
  _dotfiles_dir=$(cd -P "$(dirname "$_dotfiles_src")" && pwd)
  _dotfiles_src=$(readlink "$_dotfiles_src")
  case $_dotfiles_src in
    /*) ;;
    *) _dotfiles_src=$_dotfiles_dir/$_dotfiles_src ;;
  esac
done
_dotfiles_dir=$(cd -P "$(dirname "$_dotfiles_src")" && pwd)

for _dotfiles_module in "$_dotfiles_dir"/common.d/*.sh; do
  . "$_dotfiles_module"
done

unset _dotfiles_src _dotfiles_dir _dotfiles_module

# Machine-local overrides, untracked by design. Sourced last so they win over
# every module above.
[ -f ~/.common_shell_setup_local.sh ] && source ~/.common_shell_setup_local.sh
