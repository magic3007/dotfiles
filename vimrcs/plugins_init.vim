"---------------------
" Plugin Memagement
"---------------------

" call plug#begin('~/.vim/plugged')

" Add maktaba and codefmt to the runtimepath.
" (The latter must be installed before it can be used.)
Plug 'google/vim-maktaba'
Plug 'google/vim-codefmt'
" Also add Glaive, which is used to configure codefmt's maktaba flags. See
" `:help :Glaive` for usage.
Plug 'google/vim-glaive'
""augroup autoformat_settings
""  autocmd FileType bzl AutoFormatBuffer buildifier
""  autocmd FileType c,cpp,proto,javascript AutoFormatBuffer clang-format
""  autocmd FileType dart AutoFormatBuffer dartfmt
""  autocmd FileType go AutoFormatBuffer gofmt
""  autocmd FileType gn AutoFormatBuffer gn
""  autocmd FileType html,css,sass,scss,less,json AutoFormatBuffer js-beautify
""  autocmd FileType java AutoFormatBuffer google-java-format
""  autocmd FileType python AutoFormatBuffer yapf
""  " Alternative: autocmd FileType python AutoFormatBuffer autopep8
""  autocmd FileType rust AutoFormatBuffer rustfmt
""  autocmd FileType vue AutoFormatBuffer prettier
""augroup END

" code completion 
" Plug 'neoclide/coc.nvim', {'branch': 'release'}
" Plug 'neoclide/coc.nvim', {'do': 'yarn install --frozen-lockfile'}

" automatic add headers 
Plug 'alpertuna/vim-header'

" nerdtree
Plug 'preservim/nerdtree'

" buffergetor
Plug 'https://github.com/jeetsukumaran/vim-buffergator.git'

" gundo
Plug 'sjl/gundo.vim'

" ctrlp
Plug 'ctrlpvim/ctrlp.vim'

" ack.vim
Plug 'mileszs/ack.vim'

" syntastic
Plug 'scrooloose/syntastic'

" easymotion
Plug 'haya14busa/vim-easymotion'

" vim-markdown
Plug 'plasticboy/vim-markdown'

" fugitive
Plug 'tpope/vim-fugitive'

" youcompleteme
Plug 'valloric/youcompleteme'

" vim-snippets
Plug 'honza/vim-snippets'

" grubbox
Plug 'morhetz/gruvbox'

" vim-airline
Plug 'vim-airline/vim-airline'

" vim-airline-themes
Plug 'vim-airline/vim-airline-themes'

" surround
Plug 'tpope/vim-surround'

" tagbar
Plug 'majutsushi/tagbar'

" gitgutter
Plug 'airblade/vim-gitgutter'

" vim-clang-format
Plug 'rhysd/vim-clang-format'

" startuptime
Plug 'tweekmonster/startuptime.vim'

" vim-rooter
Plug 'airblade/vim-rooter'

" call plug#end()
