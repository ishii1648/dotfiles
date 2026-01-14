return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  event = { "BufReadPost", "BufNewFile" },
  config = function()
    require("nvim-treesitter.configs").setup({
      ensure_installed = {
        "javascript",
        "typescript",
        "tsx",
        "json",
        "html",
        "css",
        "lua",
        "yaml",
        "hcl",
        "terraform",
      },
      highlight = {
        enable = true,
      },
    })
  end,
}
