vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.highlight.on_yank({ timeout = 200 })
  end,
})

vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    require("neo-tree.command").execute({
      action = "show",
      source = "filesystem",
    })
  end,
})

--vim.api.nvim_create_autocmd("VimEnter", {
--  callback = function()
--    vim.schedule(function()
--      require("telescope.builtin").find_files()
--    end)
--  end,
--})
