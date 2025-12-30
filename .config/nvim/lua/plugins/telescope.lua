return {
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    opts = {
      defaults = {
        file_ignore_patterns = {
          "node_modules/",
          "git/",
        },
      },
      pickers = {
        find_files = {
          hidden = true,
        },
      },
    },
  },
}
