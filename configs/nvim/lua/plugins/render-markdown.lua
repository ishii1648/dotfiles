-- markdown の見出し・表・コードブロックをバッファ内で装飾表示する。
-- 折り返し（config/autocmds.lua の markdown FileType）と組み合わせて読む用途を賄う。
-- mermaid は画像を描く経路が別途必要なため、ここでは扱わない。
return {
  "MeanderingProgrammer/render-markdown.nvim",
  ft = { "markdown" },
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "nvim-tree/nvim-web-devicons",
  },
  opts = {
    -- 挿入モードでは素の markdown を見せる（編集時に装飾が邪魔になるため）
    render_modes = { "n", "v", "i", "c" },
    anti_conceal = { enabled = true },
    heading = {
      -- 見出し行の背景塗りは herdr の折り返し表示と相性が悪いので記号のみ
      width = "block",
      left_pad = 0,
    },
    code = {
      width = "block",
      min_width = 40,
    },
  },
}
