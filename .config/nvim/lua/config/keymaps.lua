local map = vim.keymap.set

local function telescope(builtin_fn)
  return function()
    require("telescope.builtin")[builtin_fn]()
  end
end

map("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- window
map("n", "H", "<C-w>h", { desc = "move left" })
map("n", "J", "<C-w>j", { desc = "move down" })
map("n", "K", "<C-w>k", { desc = "move up" })
map("n", "L", "<C-w>l", { desc = "move right" })

map("n", "<leader>wh", "<C-w>h", { desc = "move left" })
map("n", "<leader>wj", "<C-w>j", { desc = "move down" })
map("n", "<leader>wk", "<C-w>k", { desc = "move up" })
map("n", "<leader>wl", "<C-w>l", { desc = "move right" })

map("n", "<leader>wv", "<C-w>v", { desc = "vertical split" })
map("n", "<leader>ws", "<C-w>s", { desc = "horizontal split" })
map("n", "<leader>wc", "<C-w>c", { desc = "close window" })

map("n", "<D-S-f>", telescope("live_grep"), {
  desc = "Live grep (VSCode Cmd+Shift+F)",
})
map("n", "<leader>fg", telescope("live_grep"), {
  desc = "Live grep",
})

map("n", "<D-p>", telescope("find_files"), {
  desc = "Find files (VSCode Cmd+P)",
})
map("n", "<leader>ff", telescope("find_files"), {
  desc = "Find files",
})

map("n", "<leader>gg", function()
  vim.cmd("LazyGit")
end, { desc = "Open LazyGit" })
map("n", "<leader>gb", function()
  require("gitsigns").toggle_current_line_blame()
end, { desc = "Toggle Git blame (line)" })
map("n", "<leader>gB", function()
  require("gitsigns").blame_line({ full = true })
end, { desc = "Git blame (full)" })
