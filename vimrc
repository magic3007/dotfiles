source ~/vimrcs/basic.vim
source ~/vimrcs/filetypes.vim
source ~/vimrcs/plugins_config.vim
source ~/vimrcs/extended.vim

"---------------------
" Local customizations
"---------------------

" local customizations in ~/.vimrc_local
let $LOCALFILE=expand("~/.vimrc_local")
if filereadable($LOCALFILE)
    source $LOCALFILE
endif