" シンタックス・ハイライトを有効化
"foldmethodsyntax on
syntax on
" カラースキーマ
colorscheme torte
" コメントの色
hi Comment ctermfg=240

" 行番号を記述
set number
" バックスペースの設定
set backspace=indent,eol,start
" インデントやタブの設定（共通）
set expandtab
set shiftwidth=2
set softtabstop=2
set tabstop=2
" 文字エンコーディングの設定
set encoding=utf-8
" 検索時に大文字小文字を無視 (noignorecase:無視しない)
set ignorecase
" 大文字小文字の両方が含まれている場合は大文字小文字を区別
set smartcase
" インクリメンタルサーチ
set incsearch
" 検索ハイライト
set hlsearch
" ヤンクをクリップボードへ保存
set clipboard+=unnamed
" helpをデフォルトで日本語表示
set helplang=ja,en
" 折り畳みを無効化
set foldmethod=syntax
let perl_fold=1
set foldlevel=100
set fileencodings=ucs-bom,iso-2022-jp-3,iso-2022-jp,eucjp-ms,euc-jisx0213,euc-jp,sjis,cp932,utf-8

" Insertモードのときカーソルの形状を変更
let &t_SI = "\<Esc>]50;CursorShape=1\x7"
let &t_EI = "\<Esc>]50;CursorShape=0\x7"
" キーの割り当て
nmap <C-m> :PrevimOpen<CR>

" 外部ファイルのインポート
if filereadable(expand("~/.vim/Utils.vim"))
    source ~/.vim/Utils.vim
endif

if filereadable(expand("~/.vim/NeoBundle.vim"))
    source ~/.vim/NeoBundle.vim
endif

" ファイルタイプ別にインデントを設定
augroup fileTypeIndent
    autocmd!
    autocmd BufNewFile,BufRead *.py  setlocal tabstop=4 softtabstop=4 shiftwidth=4
    autocmd BufNewFile,BufRead *.rb  setlocal tabstop=2 softtabstop=2 shiftwidth=2
    autocmd BufNewFile,BufRead *.yml setlocal tabstop=2 softtabstop=2 shiftwidth=2
    autocmd BufNewFile,BufRead *.md  setlocal tabstop=2 softtabstop=2 shiftwidth=2
    autocmd BufNewFile,BufRead *.js  setlocal tabstop=2 softtabstop=2 shiftwidth=2
augroup END

" 拡張子を基にファイル・タイプを定義
augroup fileTypeDefine
    autocmd!
    autocmd BufNewFile,BufRead *.md  set filetype=markdown
augroup END

" 対象のファイルを保存時にSCPで対象ホストに転送
augroup transmit
    autocmd!
    autocmd BufWritePost ~/MTLInfra/monitor-scripts/monitor/* :call SyncFile("/Users/mtlbihin223/MTLInfra/monitor-scripts/monitor", "monitor:/home/webmanager/")
augroup END


if has('vim_starting')
    " 挿入モード時に非点滅の縦棒タイプのカーソル
    let &t_SI .= "\e[6 q"
    " ノーマルモード時に非点滅のブロックタイプのカーソル
    let &t_EI .= "\e[2 q"
    " 置換モード時に非点滅の下線タイプのカーソル
    let &t_SR .= "\e[4 q"
endif
