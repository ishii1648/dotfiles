return {
  "mg979/vim-visual-multi",
  branch = "master",
  init = function()
    -- Ghosttyから送信されるCmd+Dのエスケープシーケンスをマッピング
    vim.g.VM_maps = {
      ["Find Under"] = "<C-d>",
      ["Find Subword Under"] = "<C-d>",
    }
    vim.keymap.set("n", "\x1b[100;9u", "<C-d>", { remap = true })
  end,
}
