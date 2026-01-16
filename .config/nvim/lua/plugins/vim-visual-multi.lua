return {
  "mg979/vim-visual-multi",
  branch = "master",
  init = function()
    -- Ghosttyから送信されるCmd+Dのエスケープシーケンスをマッピング
    -- Ctrl+d は本来の半ページスクロールを維持するため、Cmd+D のみ対応
    vim.keymap.set("n", "\x1b[100;9u", function()
      -- VM_maps でCtrl+nがデフォルトなので、Cmd+D を Ctrl+n にマップ
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-n>", true, false, true), "n", false)
    end, { desc = "Find word under cursor (multi-cursor)" })
  end,
}
