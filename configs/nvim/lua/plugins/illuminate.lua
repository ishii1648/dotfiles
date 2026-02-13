return {
  "RRethy/vim-illuminate",
  event = { "BufReadPost", "BufNewFile" },
  config = function()
    require("illuminate").configure({
      providers = { "treesitter", "regex" },
      delay = 200,
      filetypes_denylist = { "neo-tree", "toggleterm" },
    })
  end,
}
