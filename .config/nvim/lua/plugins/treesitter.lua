return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  event = { "BufReadPost", "BufNewFile" },
  config = function()
    require("nvim-treesitter").install({
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
    })
  end,
}
