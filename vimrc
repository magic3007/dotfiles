" Comments in Vimscript start with a `"`.

" Vim is based on Vi. Setting `nocompatible` switches from the default
" Vi-compatibility mode and enables useful Vim functionality. This
" configuration option turns out not to be necessary for the file named
" '~/.vimrc', because Vim automatically enters nocompatible mode if that file
" is present. But we're including it here just in case this config file is
" loaded some other way (e.g. saved as `foo`, and then Vim started with
" `vim -u foo`).
set nocompatible

" Disable the default Vim startup messages.
set shortmess+=I

" -------------------
"  Syntax and indent
" -------------------

" Turn on syntax highlighting.
syntax on

" show matching braces when text indicator is over them
set showmatch 

" highlight current line, but only in active window
augroup CursorLineOnlyInActiveWindow
    autocmd!
    autocmd VimEnter,WinEnter,BufWinEnter * setlocal cursorline
    autocmd WinLeave * setlocal nocursorline
augroup END


" vim can autodetect this based on $TERM (e.g. 'xterm-256color')
" but it can be set to force 256 colors
" set t_Co=256
if has('gui_running')
    colorscheme solarized8 
    let g:lightline = {'colorscheme': 'solarized'}
elseif &t_Co < 256
    colorscheme default
    set nocursorline " looks bad in this mode
else
    set background=dark
    let g:solarized_termcolors=256 " instead of 16 color with mapping in terminal
    colorscheme  gruvbox
    set guifont=Monaco:h17
    " customized colors
    highlight SignColumn ctermbg=234
    highlight StatusLine cterm=bold ctermfg=245 ctermbg=235
    highlight StatusLineNC cterm=bold ctermfg=245 ctermbg=235
    let g:lightline = {'colorscheme': 'dark'}
    highlight SpellBad cterm=underline
    " patches
    highlight CursorLineNr cterm=NONE
endif

" enable file type detection
filetype plugin indent on 

set autoindent

"---------------------
" Basic editing config
"---------------------

" Show line numbers
set number


" This enables relative line numbering mode. With both number and
" relativenumber enabled, the current line shows the true line number, while
" all other lines (above and below) are numbered relative to the current line.
" This is useful because you can tell, at a glance, what count is needed to
" jump up or down to a particular line, by {count}k to go up or {count}j to go
" down.
" set relativenumber

" Always show the status line at the bottom, even if you only have one window open.
set laststatus=2

" The backspace key has slightly unintuitive behavior by default. For example,
" by default, you can't backspace before the insertion point set with 'i'.
" This configuration makes backspace behave more reasonably, in that you can
" backspace over anything.
set backspace=indent,eol,start

" By default, Vim doesn't let you hide a buffer (i.e. have a buffer that isn't
" shown in any window) that has unsaved changes. This is to prevent you from "
" forgetting about unsaved changes and then quitting e.g. via `:qa!`. We find
" hidden buffers helpful enough to disable this protection. See `:help hidden`
" for more information on this.
set hidden

" This setting makes search case-insensitive when all characters in the string
" being searched are lowercase. However, the search becomes case-sensitive if
" it contains any capital letters. This makes searching more convenient.
set ignorecase
set smartcase

" Enable searching as you type, rather than waiting till you press enter.
set incsearch

" Highlight search
set hls

" set list to see tabs and non-breakable spaces
set listchars=tab:>>,nbsp:~ 

set lbr " line break

set scrolloff=5 " show lines above and below cursor (when possible)

" hide mode
set noshowmode 

" always keep status bar on 
set laststatus=2

set backspace=indent,eol,start " allow backspacing over everything

set timeout timeoutlen=1000 ttimeoutlen=100 " fix slow O inserts

set lazyredraw " skip redrawing screen in some cases

set autochdir " automatically set current directory to directory of last opened file

set hidden " allow auto-hiding of edited buffers

set history=8192 " more history

" suppress inserting two spaces between sentences
" use 4 spaces instead of tabs during formatting
" set nojoinspaces 

" set tab and space options 
set expandtab
set tabstop=4
set shiftwidth=4
set softtabstop=4

set mouse+=a " enable mouse mode (scrolling, selection, etc)
set selection=exclusive
set selectmode=mouse,key
if &term =~ '^screen'
    " tmux knows the extended mouse mode
    set ttymouse=xterm2
endif
set nofoldenable " disable folding by default

" Open new windows to right and bottom, which feels
" more natural than Vim's defualt.
set splitbelow
set splitright

"禁止生成临时文件
set nobackup
set noswapfile

" 打开状态栏标尺
set ruler                   

" 突出显示当前行
set cursorline              
hi CursorLine   cterm=NONE ctermbg=darkred ctermfg=white guibg=darkred guifg=white
hi CursorLine   cterm=NONE ctermbg=darkgrey guibg=darkgrey

" 匹配括号高亮的时间（单位是十分之一秒）
set matchtime=1

" maximum number of tabs 
set tabpagemax=100

" 共享剪贴板  
set clipboard+=unnamed 

" 在处理未保存或只读文件的时候，弹出确认
set confirm


" disable audible bell
set noerrorbells visualbell t_vb=

" -------------------
"   Keymap
" -------------------
  
" Unbind some useless/annoying default key bindings.
" 'Q' in normal mode enters Ex mode. You almost never want this.
nmap Q <Nop> 

nmap <C-a> <Nop>

nmap <C-x> <Nop>

" Try to prevent bad habits like using the arrow keys for movement. This is
" not the only possible bad habit. For example, holding down the h/j/k/l keys
" for movement, rather than using more efficient movement commands, is also a
" bad habit. The former is enforceable through a .vimrc, while we don't know
" how to prevent the latter.
" Do this in normal mode...
nnoremap <Left>  :echoe "Use h"<CR>
nnoremap <Right> :echoe "Use l"<CR>
nnoremap <Up>    :echoe "Use k"<CR>
nnoremap <Down>  :echoe "Use j"<CR>
" ...and in insert mode
inoremap <Left>  <ESC>:echoe "Use h"<CR>
inoremap <Right> <ESC>:echoe "Use l"<CR>
inoremap <Up>    <ESC>:echoe "Use k"<CR>
inoremap <Down>  <ESC>:echoe "Use j"<CR>

" complete chars 
:inoremap .. ->
:inoremap ( ()<ESC>i
:inoremap ) <c-r>=ClosePair(')')<CR>
:inoremap { {}<ESC>i
":inoremap { {<CR>}<ESC>O
:inoremap } <c-r>=ClosePair('}')<CR>
:inoremap [ []<ESC>i
:inoremap ] <c-r>=ClosePair(']')<CR>
":inoremap " ""<ESC>i
":inoremap ' ''<ESC>i
function! ClosePair(char)
    if getline('.')[col('.') - 1] == a:char
        return "\<Right>"
    else
        return a:char
    endif
endfunction

" quicker window movement
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-h> <C-w>h
nnoremap <C-l> <C-w>l

" movement relative to display lines
nnoremap <silent> <Leader>d :call ToggleMovementByDisplayLines()<CR>
function SetMovementByDisplayLines()
    noremap <buffer> <silent> <expr> k v:count ? 'k' : 'gk'
    noremap <buffer> <silent> <expr> j v:count ? 'j' : 'gj'
    noremap <buffer> <silent> 0 g0
    noremap <buffer> <silent> $ g$
endfunction
function ToggleMovementByDisplayLines()
    if !exists('b:movement_by_display_lines')
        let b:movement_by_display_lines = 0
    endif
    if b:movement_by_display_lines
        let b:movement_by_display_lines = 0
        silent! nunmap <buffer> k
        silent! nunmap <buffer> j
        silent! nunmap <buffer> 0
        silent! nunmap <buffer> $
    else
        let b:movement_by_display_lines = 1
        call SetMovementByDisplayLines()
    endif
endfunction

" toggle relative numbering
nnoremap <C-n> :set rnu!<CR>

" save read-only files
command -nargs=0 Sudow w !sudo tee % >/dev/null


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

"---------------------
" Local customizations
"---------------------

" local customizations in ~/.vimrc_local
let $LOCALFILE=expand("~/.vimrc_local")
if filereadable($LOCALFILE)
    source $LOCALFILE
endif
