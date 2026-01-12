local map = vim.keymap.set

local function telescope(builtin_fn)
  return function()
    require("telescope.builtin")[builtin_fn]()
  end
end

-- Custom git_worktrees picker with worktree creation support
local function git_worktrees()
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local previewers = require("telescope.previewers")

  -- Check if in git repo
  local git_dir = vim.fn.system("git rev-parse --git-dir 2>/dev/null")
  if vim.v.shell_error ~= 0 or git_dir == "" then
    vim.notify("Not in a git repository", vim.log.levels.ERROR)
    return
  end

  -- Get worktree list
  local output = vim.fn.system("git worktree list")
  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to get worktree list", vim.log.levels.ERROR)
    return
  end

  local worktrees = {}
  for line in output:gmatch("[^\n]+") do
    local path, hash, branch = line:match("^(%S+)%s+(%S+)%s+%[(.+)%]")
    if path and branch then
      table.insert(worktrees, {
        path = path,
        hash = hash,
        branch = branch,
      })
    end
  end

  -- Get main worktree path for new worktree creation
  local main_worktree_output = vim.fn.system("git worktree list --porcelain | head -n1")
  local main_worktree = main_worktree_output:match("worktree (.+)")
  if main_worktree then
    main_worktree = main_worktree:gsub("\n", "")
  end

  pickers
    .new({}, {
      prompt_title = "Git Worktrees (type to create new)",
      finder = finders.new_table({
        results = worktrees,
        entry_maker = function(entry)
          local is_current = entry.path == vim.fn.getcwd()
          local marker = is_current and "* " or "  "
          return {
            value = entry,
            display = marker .. entry.branch .. " (" .. entry.path .. ")",
            ordinal = entry.branch .. " " .. entry.path,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      previewer = previewers.new_termopen_previewer({
        get_command = function(entry)
          return { "git", "-C", entry.value.path, "log", "--oneline", "-10" }
        end,
      }),
      attach_mappings = function(prompt_bufnr, _)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          local input = action_state.get_current_line()
          actions.close(prompt_bufnr)

          if selection and selection.value then
            -- Switch to existing worktree
            local path = selection.value.path
            if path == vim.fn.getcwd() then
              vim.notify("Already in this worktree", vim.log.levels.WARN)
              return
            end
            vim.fn.chdir(path)
            vim.notify("Switched to worktree: " .. selection.value.branch, vim.log.levels.INFO)
          elseif input and input ~= "" and main_worktree then
            -- Create new worktree
            local confirm = vim.fn.confirm("Create new worktree '" .. input .. "'?", "&Yes\n&No", 2)
            if confirm == 1 then
              local worktree_path = main_worktree .. "/.worktrees/" .. input
              vim.fn.mkdir(main_worktree .. "/.worktrees", "p")
              local result = vim.fn.system(
                string.format(
                  "git worktree add %s -b %s",
                  vim.fn.shellescape(worktree_path),
                  vim.fn.shellescape(input)
                )
              )
              if vim.v.shell_error == 0 then
                vim.fn.chdir(worktree_path)
                vim.notify("Created worktree: " .. input, vim.log.levels.INFO)
              else
                vim.notify("Failed to create worktree: " .. result, vim.log.levels.ERROR)
              end
            end
          end
        end)
        return true
      end,
    })
    :find()
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
map("n", "<leader>gw", git_worktrees, { desc = "Switch/Create git worktree" })
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
