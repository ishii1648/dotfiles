local map = vim.keymap.set

local function telescope(builtin_fn)
  return function()
    require("telescope.builtin")[builtin_fn]()
  end
end

-- Custom git_branches picker with branch creation support
local function git_branches_with_create()
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  require("telescope.builtin").git_branches({
    attach_mappings = function(prompt_bufnr, _)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        local input = action_state.get_current_line()

        actions.close(prompt_bufnr)

        if selection and selection.value then
          -- 既存ブランチにチェックアウト
          local branch = selection.value:gsub("^origin/", "")
          vim.fn.system("git checkout " .. vim.fn.shellescape(branch))
          if vim.v.shell_error == 0 then
            vim.notify("Switched to branch: " .. branch, vim.log.levels.INFO)
          else
            vim.notify("Failed to checkout branch: " .. branch, vim.log.levels.ERROR)
          end
        elseif input and input ~= "" then
          -- 新規ブランチ作成（確認ダイアログ付き）
          local confirm = vim.fn.confirm(
            "Create and checkout new branch '" .. input .. "'?",
            "&Yes\n&No",
            2
          )
          if confirm == 1 then
            vim.fn.system("git checkout -b " .. vim.fn.shellescape(input))
            if vim.v.shell_error == 0 then
              vim.notify("Created and switched to branch: " .. input, vim.log.levels.INFO)
            else
              vim.notify("Failed to create branch: " .. input, vim.log.levels.ERROR)
            end
          end
        end
      end)
      return true
    end,
  })
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

-- for Git
map("n", "<leader>gb", git_branches_with_create, { desc = "Switch/Create git branch" })
map("n", "<leader>gp", "<cmd>!git pull<CR>", { desc = "Git pull" })

-- GitHub link
map({ "n", "v" }, "<leader>gl", function()
  require("utils.github-link").copy_github_url(false)
end, { desc = "Copy GitHub permalink" })
map({ "n", "v" }, "<leader>gL", function()
  require("utils.github-link").copy_github_url(true)
end, { desc = "Copy GitHub link (branch)" })

-- Claude Code reference
map({ "n", "v" }, "<leader>cc", function()
  require("utils.claude-ref").copy_claude_ref()
end, { desc = "Copy Claude Code reference" })
