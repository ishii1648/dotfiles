return {
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    },
    opts = {
      defaults = {
        file_ignore_patterns = {
          ".git/",
          ".terraform/",
          ".worktree/",
        },
      },
      pickers = {
        find_files = {
          hidden = true,
          find_command = { "fd", "--type", "f", "--strip-cwd-prefix" },
        },
      },
    },
    config = function(_, opts)
      local telescope = require("telescope")
      telescope.setup(opts)
      telescope.load_extension("fzf")
    end,
  },
}
