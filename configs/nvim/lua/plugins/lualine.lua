local worktree_cache = {
  is_worktree = false,
  cwd = nil,
}

-- 配色は 'background' に追随して切り替わる（lua/plugins/colorscheme.lua）ため、
-- ハードコードした Dracula 色のままだとライト背景で沈む。両方の palette を持つ。
local palette = {
  dark = { green = "#50fa7b", red = "#ff5555" }, -- Dracula
  light = { green = "#40a02b", red = "#d20f39" }, -- Catppuccin Latte
}

local function color_of(name)
  return (palette[vim.o.background] or palette.dark)[name]
end

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

vim.api.nvim_create_autocmd({ "DirChanged" }, {
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
              return { fg = color_of("green") }
            end
          end,
        },
        "diff",
      },
      lualine_c = {
        "filename",
        {
          function()
            if vim.bo.readonly then
              return "[RO]"
            end
            return ""
          end,
          color = function()
            return { fg = color_of("red") }
          end,
        },
      },
    },
  },
}
