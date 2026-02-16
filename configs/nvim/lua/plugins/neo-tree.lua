return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    "MunifTanjim/nui.nvim",
  },
  cmd = "Neotree",
  keys = {
    { "<leader>e", "<cmd>Neotree toggle<CR>", desc = "Explorer" },
  },
  opts = {
    async_directory_scan = "auto",
    git_status = {
      async = true,
    },
    filesystem = {
      bind_to_cwd = true,
      follow_symlinks = false,
      use_libuv_file_watcher = true,
      follow_current_file = {
        enabled = true,
      },
      filtered_items = {
        visible = false,
        hide_dotfiles = false,
        hide_gitignored = true,
        hide_by_name = {
          ".git",
          ".terraform",
          ".worktree",
          "node_modules",
        },
        never_show = {
          ".git",
          ".terraform",
          ".worktree",
          "node_modules",
        },
        always_show = {
          ".claude",
          ".outputs",
        },
      },
    },
  },
}
