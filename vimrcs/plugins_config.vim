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
nnoremap <Leader>N :NERDTreeToggle<CR>
nnoremap <Leader>F :NERDTreeFind<CR>

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

" youcompleteme

" force YCM to immediately recompile your file and display any new diagnostics it encounters.
nnoremap <F5> :YcmForceCompileAndDiagnostics<CR>

" This will print out various debug information for the current file. Useful to see what compile commands will be used for the file if you're using the semantic completion engine.
" :YcmDebugInfo

" GoTo Commands
" When moving the cursor, the subcommands add entries to Vim's jumplist,
" <C-I> jump forward
" <C-O> jump back to where you were before invoking the command
" :h jumplist for details

