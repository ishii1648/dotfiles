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

-- Helmfile file type detection (use gotmpl for Go template support)
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = { "helmfile.yaml", "helmfile*.yaml", "*/helmfile.d/*.yaml" },
  callback = function()
    vim.bo.filetype = "gotmpl"
  end,
})

-- Helm file type detection
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = { "*/templates/*.yaml", "*/templates/*.tpl", "Chart.yaml", "values*.yaml" },
  callback = function()
    vim.bo.filetype = "helm"
  end,
})

-- 散文主体の markdown だけ折り返す（options.lua の wrap = false は他 filetype で維持）
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown" },
  callback = function(args)
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true -- 単語の途中で折り返さない
    vim.opt_local.breakindent = true -- 折り返し後も箇条書きのインデントを保つ
    vim.opt_local.showbreak = "↪ "
    -- 折り返し後は論理行ではなく表示行で動かないと j/k が数行飛ぶ
    for _, key in ipairs({ "j", "k" }) do
      vim.keymap.set("n", key, "g" .. key, { buffer = args.buf, desc = "表示行で移動" })
    end
  end,
})

-- Enable treesitter highlighting for supported filetypes
vim.api.nvim_create_autocmd("FileType", {
  pattern = {
    "javascript",
    "typescript",
    "tsx",
    "json",
    "html",
    "css",
    "lua",
    "yaml",
    "gotmpl",
    "helm",
    "hcl",
    "terraform",
    "markdown",
  },
  callback = function()
    pcall(vim.treesitter.start)
  end,
})
