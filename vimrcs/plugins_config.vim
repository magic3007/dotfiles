"---------------------
" Plugin Memagement
"---------------------

if empty(glob('~/.vim/autoload/plug.vim'))
      silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
                        \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
      autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif
" Useful command: ':PlugInstall'

call plug#begin('~/.vim/plugged')

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

" incsearch
Plug 'haya14busa/incsearch.vim'

" incsearch-easymotion
Plug 'haya14busa/incsearch-easymotion.vim'

" argwrap
Plug 'foosoft/vim-argwrap'

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

call plug#end()


"---------------------
" Plugin configuration
"---------------------


" codefmt
call glaive#Install()
" set to google style 
Glaive codefmt clang_format_style=google

" vim-header 
" https://github.com/alpertuna/vim-header
let g:header_field_author = 'Jing Mai'
let g:header_field_author_email = 'jingmai@pku.edu.cn'
" toggle automatic add header 
let g:header_auto_add_header = 0
let g:header_field_timestamp_format = '%m.%d.%Y'
" useful commands 
" AddHeader, AddMinHeader, AddMITLicense, AddApacheLicense, 


" nerdtree
nnoremap <Leader>n :NERDTreeToggle<CR>
nnoremap <Leader>f :NERDTreeFind<CR>

" buffergator
let g:buffergator_suppress_keymaps = 1
nnoremap <Leader>b :BuffergatorToggle<CR>

" gundo
nnoremap <Leader>u :GundoToggle<CR>
if has('python3')
    let g:gundo_prefer_python3 = 1
endif

" ctrlp
nnoremap ; :CtrlPBuffer<CR>
let g:ctrlp_switch_buffer = 0
let g:ctrlp_show_hidden = 1

" ack.vim
command -nargs=+ Gag Gcd | Ack! <args>
nnoremap K :Gag "\b<C-R><C-W>\b"<CR>:cw<CR>
if executable('ag')
    let g:ctrlp_user_command = 'ag %s -l --nocolor --hidden -g ""'
    let g:ackprg = 'ag --vimgrep'
endif

" syntastic
let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 1
let g:syntastic_check_on_wq = 0
let g:syntastic_mode_map = {
    \ 'mode': 'passive',
    \ 'active_filetypes': [],
    \ 'passive_filetypes': []
\}
nnoremap <Leader>s :SyntasticCheck<CR>
nnoremap <Leader>r :SyntasticReset<CR>
nnoremap <Leader>i :SyntasticInfo<CR>
nnoremap <Leader>m :SyntasticToggleMode<CR>

" easymotion
map <Space> <Plug>(easymotion-prefix)

" incsearch
map / <Plug>(incsearch-forward)
map ? <Plug>(incsearch-backward)
map g/ <Plug>(incsearch-stay)

" incsearch-easymotion
map z/ <Plug>(incsearch-easymotion-/)
map z? <Plug>(incsearch-easymotion-?)
map zg/ <Plug>(incsearch-easymotion-stay)

" argwrap
nnoremap <Leader>w :ArgWrap<CR>

noremap <Leader>x :OverCommandLine<CR>

" markdown
let g:vim_markdown_fenced_languages = [
    \ 'bash=sh',
    \ 'c',
    \ 'coffee',
    \ 'erb=eruby',
    \ 'javascript',
    \ 'json',
    \ 'perl',
    \ 'python',
    \ 'ruby',
    \ 'yaml',
    \ 'go',
    \ 'racket',
\]
let g:vim_markdown_syntax_conceal = 0
let g:vim_markdown_folding = 1

" fugitive
set tags^=.git/tags;~