return {
  name = "viewer-mode",
  dir = vim.fn.stdpath("config"),
  config = function()
    -- Toggle viewer mode for current buffer
    vim.api.nvim_create_user_command("ViewerMode", function()
      local readonly = not vim.bo.readonly
      vim.bo.readonly = readonly
      vim.bo.modifiable = not readonly
      vim.notify("Viewer Mode: " .. (readonly and "ON" or "OFF"), vim.log.levels.INFO)
    end, {})

    -- Toggle viewer mode for all buffers
    vim.api.nvim_create_user_command("ViewerModeAll", function(opts)
      local enable = opts.args ~= "off"
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == "" then
          vim.bo[buf].readonly = enable
          vim.bo[buf].modifiable = not enable
        end
      end
      vim.notify("Viewer Mode All: " .. (enable and "ON" or "OFF"), vim.log.levels.INFO)
    end, { nargs = "?" })
  end,
}
