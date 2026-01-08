local M = {}

--- Get GitHub URL for current file and line(s)
---@param use_branch boolean Use branch name instead of commit hash
---@return string|nil url The GitHub URL or nil on error
local function get_github_url(use_branch)
  local file = vim.fn.expand('%:p')

  -- Get line range (works for both normal and visual mode)
  local mode = vim.fn.mode()
  local line_start, line_end

  if mode == 'v' or mode == 'V' or mode == '\22' then
    -- Visual mode: get selection range
    line_start = vim.fn.line('v')
    line_end = vim.fn.line('.')
  else
    -- Normal mode: current line only
    line_start = vim.fn.line('.')
    line_end = line_start
  end

  -- Ensure start <= end
  if line_start > line_end then
    line_start, line_end = line_end, line_start
  end

  -- Get all git info in one shell call
  local ref_cmd = use_branch and 'git rev-parse --abbrev-ref HEAD' or 'git rev-parse HEAD'
  local cmd = string.format(
    'git config --get remote.origin.url && git rev-parse --show-toplevel && %s',
    ref_cmd
  )
  local output = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    vim.notify('Not a git repository', vim.log.levels.ERROR)
    return nil
  end

  local lines = vim.split(output, '\n', { trimempty = true })
  if #lines < 3 then
    vim.notify('Failed to get git info', vim.log.levels.ERROR)
    return nil
  end

  local remote = lines[1]
  local root = lines[2]
  local ref = lines[3]

  -- Convert SSH to HTTPS format
  -- git@github.com:user/repo.git -> https://github.com/user/repo
  local url = remote
    :gsub('git@github%.com:', 'https://github.com/')
    :gsub('%.git$', '')

  -- Get relative path from git root
  local rel_path = file:sub(#root + 2)

  -- Build URL with line range
  local result
  if line_start == line_end then
    result = string.format('%s/blob/%s/%s#L%d', url, ref, rel_path, line_start)
  else
    result = string.format('%s/blob/%s/%s#L%d-L%d', url, ref, rel_path, line_start, line_end)
  end

  return result
end

--- Copy GitHub URL to clipboard
---@param use_branch boolean Use branch name instead of commit hash
function M.copy_github_url(use_branch)
  local url = get_github_url(use_branch)
  if url then
    vim.fn.setreg('+', url)
    vim.notify('Copied: ' .. url, vim.log.levels.INFO)
  end
end

return M
