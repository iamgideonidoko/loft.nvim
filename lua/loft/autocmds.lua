local actions = require("loft.actions")
local utils = require("loft.utils")
local registry_instance = require("loft.registry")
local autocmds = {}

autocmds.setup = function()
  vim.api.nvim_create_autocmd({ "BufEnter", "FocusGained" }, {
    group = utils.get_augroup("DeleteMissingFileBuffer", true),
    callback = function()
      if not registry_instance.opts.auto_delete_missing_file_bufs then
        return
      end
      local buf = vim.api.nvim_get_current_buf()
      local file_path = vim.api.nvim_buf_get_name(buf)
      -- Fast-exit: skip unnamed, URI-scheme, non-normal buffers.
      if
        file_path == ""
        or file_path:match("^%a[%w+.-]+://")
        or vim.bo[buf].buftype ~= ""
        or vim.fn.buflisted(buf) == 0
      then
        return
      end
      -- Non-blocking async stat. The callback fires on the main thread
      -- (via vim.schedule inside async_stat) with zero UI lag.
      -- It also warms the cache so subsequent buf_has_deleted_file calls
      -- for the same path are served instantly.
      utils.async_stat(file_path, function(file_exists)
        if not file_exists then
          actions.close_buffer({ buf = buf, force = true })
        end
      end)
    end,
  })
end

return autocmds
