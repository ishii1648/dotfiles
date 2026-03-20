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
          "%.git/",
          "%.terraform/",
          "%.worktree/",
        },
      },
      pickers = {
        find_files = {
          hidden = true,
          find_command = {
            "bash",
            "-c",
            "fd --type f --strip-cwd-prefix --hidden; "
              .. "fd --type f --hidden --no-ignore-vcs . .outputs/claude 2>/dev/null || true; "
              .. "fd --type f --hidden --no-ignore-vcs . tickets 2>/dev/null || true",
          },
        },
      },
    },
    config = function(_, opts)
      local ignore_overrides = vim.fn.stdpath("config") .. "/ignore_overrides"
      opts.pickers.live_grep = {
        additional_args = { "--ignore-file", ignore_overrides },
      }

      local telescope = require("telescope")
      telescope.setup(opts)
      telescope.load_extension("fzf")
    end,
  },
}
