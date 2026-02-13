vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("config.options")
require("config.keymaps")
require("config.autocmds")

require("bootstrap")

-- ローカル設定（オプション、git管理外）
pcall(require, "local")

