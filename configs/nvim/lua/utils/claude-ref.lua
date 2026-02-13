local M = {}

--- Get Claude Code reference for current file and line(s)
---@return string ref The reference in @file#L{start}-{end} format
local function get_claude_ref()
  -- 相対パスを取得
  local file = vim.fn.expand('%:.')

  -- 行範囲を取得（ビジュアルモード/通常モード両対応）
  local mode = vim.fn.mode()
  local line_start, line_end

  if mode == 'v' or mode == 'V' or mode == '\22' then
    line_start = vim.fn.line('v')
    line_end = vim.fn.line('.')
  else
    line_start = vim.fn.line('.')
    line_end = line_start
  end

  -- start <= end を保証
  if line_start > line_end then
    line_start, line_end = line_end, line_start
  end

  -- 参照文字列を生成
  if line_start == line_end then
    return string.format('@%s#L%d', file, line_start)
  else
    return string.format('@%s#L%d-%d', file, line_start, line_end)
  end
end

--- Copy Claude Code reference to clipboard
function M.copy_claude_ref()
  local ref = get_claude_ref()
  vim.fn.setreg('+', ref)
  vim.notify('Copied: ' .. ref, vim.log.levels.INFO)
end

return M
