return {
  "nvim-treesitter/nvim-treesitter",
  lazy = false,
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
      "yaml",
      "gotmpl",
      "hcl",
      "terraform",
    })
  end,
}
