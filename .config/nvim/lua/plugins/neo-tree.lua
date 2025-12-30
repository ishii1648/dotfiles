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
          "node_modules",
        },
        never_show = {
          ".git",
          "node_modules",
        },
      },
    },
  },
}
