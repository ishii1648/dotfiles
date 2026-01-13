local worktree_cache = {
  is_worktree = false,
  cwd = nil,
}

local function is_in_worktree()
  local cwd = vim.fn.getcwd()
  if worktree_cache.cwd == cwd then
    return worktree_cache.is_worktree
  end

  local count = vim.fn.system("git worktree list 2>/dev/null | wc -l")
  worktree_cache.cwd = cwd
  worktree_cache.is_worktree = tonumber(count:gsub("%s+", "")) and tonumber(count:gsub("%s+", "")) > 1
  return worktree_cache.is_worktree
end

vim.api.nvim_create_autocmd({ "DirChanged", "BufEnter" }, {
  callback = function()
    worktree_cache.cwd = nil
  end,
})

return {
  "nvim-lualine/lualine.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = {
    sections = {
      lualine_b = {
        {
          "branch",
          color = function()
            if is_in_worktree() then
              return { fg = "#50fa7b" }
            end
          end,
        },
        "diff",
        "diagnostics",
      },
    },
  },
}
