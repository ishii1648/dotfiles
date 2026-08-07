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
      -- render-markdown.nvim は markdown_inline も要求する
      "markdown",
      "markdown_inline",
    })
  end,
}
