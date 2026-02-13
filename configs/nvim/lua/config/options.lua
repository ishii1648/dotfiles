local opt = vim.opt

opt.number = true
opt.relativenumber = false
opt.wrap = false

opt.tabstop = 2
opt.shiftwidth = 2
opt.expandtab = true

opt.termguicolors = true
opt.signcolumn = "yes"

opt.ignorecase = true
opt.smartcase = true

opt.splitright = true
opt.splitbelow = true

opt.cursorline = true
opt.scrolloff = 5

opt.backup = false
opt.writebackup = false
opt.swapfile = false
opt.undofile = true
opt.clipboard = "unnamedplus"

vim.g.loaded_netrw = 1

-- Viewer用設定

-- Treesitter折りたたみ
opt.foldmethod = "expr"
opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
opt.foldlevel = 99
opt.foldlevelstart = 99

-- スムーズスクロール (Neovim 0.10+)
opt.smoothscroll = true
opt.mousescroll = "ver:3,hor:6"
