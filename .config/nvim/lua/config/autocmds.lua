vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.highlight.on_yank({ timeout = 200 })
  end,
})

vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    vim.defer_fn(function()
      require("neo-tree.command").execute({
        action = "show",
        source = "filesystem",
      })
    end, 100)
  end,
})

--vim.api.nvim_create_autocmd("VimEnter", {
--  callback = function()
--    vim.schedule(function()
--      require("telescope.builtin").find_files()
--    end)
--  end,
--})

-- Helm file type detection
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = {
    "*/templates/*.yaml",
    "*/templates/*.tpl",
    "Chart.yaml",
    "values*.yaml",
    "helmfile*.yaml",
    "*/helmfile.d/*.yaml",
  },
  callback = function()
    vim.bo.filetype = "helm"
  end,
})
