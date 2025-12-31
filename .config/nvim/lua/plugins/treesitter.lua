return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  config = function()
    require("nvim-treesitter").install({
      "javascript",
      "typescript",
      "tsx",
      "json",
      "html",
      "css",
      "lua",
    })
  end,
}
