-- ghostty / herdr は macOS の外観設定に追随する（light:Catppuccin Latte,dark:Dracula）。
-- nvim も端末の背景に合わせて配色を切り替え、ライト端末の中で nvim だけ暗く残らないようにする。
--
-- 'background' は TUI が起動時に OSC 11 で端末へ背景色を問い合わせて設定する
-- （:help 'background'）。herdr は ]11;rgb: に応答するのでペインの中からでも判定できる
-- （ADR-093 で Claude Code の theme = auto を通したのと同じ経路）。
-- 端末が応答しない場合は既定の dark のままなので、従来どおり Dracula になる。
local schemes = {
  dark = "dracula",
  light = "catppuccin-latte",
}

-- colorscheme ファイル自身が 'background' を書き換える（dracula は `set background=dark`）ため、
-- OptionSet からの再入を止める
local applying = false

local function apply()
  if applying then
    return
  end
  applying = true
  local ok, err = pcall(vim.cmd.colorscheme, schemes[vim.o.background] or schemes.dark)
  applying = false
  if not ok then
    vim.notify(tostring(err), vim.log.levels.WARN)
  end
end

return {
  {
    -- ライト側。dracula より先に読ませたいので priority を 1 つ上げる
    -- （lazy.nvim は priority の高い start plugin から読み込む）。
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1001,
  },
  {
    "dracula/vim",
    name = "dracula",
    lazy = false,
    priority = 1000,
    config = function()
      -- ここが走る時点で catppuccin も読み込み済みなので、どちらの側にも切り替えられる
      apply()

      -- 起動後に 'background' が変わったとき（端末のテーマ変更通知を TUI が拾った場合や、
      -- 手動で `:set background=light` したとき）も追随させる
      vim.api.nvim_create_autocmd("OptionSet", {
        pattern = "background",
        callback = apply,
      })
    end,
  },
}
