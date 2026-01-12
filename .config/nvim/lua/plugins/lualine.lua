-- Custom branch component with worktree awareness
local function git_branch_worktree()
  local branch = vim.fn.system("git branch --show-current 2>/dev/null"):gsub("\n", "")
  if branch == "" then
    return ""
  end
  return branch
end

local function is_worktree_active()
  local count = vim.fn.system("git worktree list 2>/dev/null | wc -l"):gsub("%s+", "")
  return tonumber(count) and tonumber(count) > 1
end

return {
  "nvim-lualine/lualine.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = {
    sections = {
      lualine_b = {
        {
          git_branch_worktree,
          icon = "",
          color = function()
            if is_worktree_active() then
              return { fg = "#50fa7b" } -- bright green
            else
              return { fg = "#9a9a9a" } -- gray
            end
          end,
        },
        "diff",
        "diagnostics",
      },
    },
  },
}
