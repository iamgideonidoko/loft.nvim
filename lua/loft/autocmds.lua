local actions = require("loft.actions")
local utils = require("loft.utils")
local registry_instance = require("loft.registry")
local autocmds = {}

autocmds.setup = function()
  -- On focus return, warm the stat cache for every registry buffer asynchronously.
  -- This runs before any BufEnter fires, so by the time _update()'s vim.schedule
  -- callback calls clean(), all registry buffer stats are already cached.
  vim.api.nvim_create_autocmd("FocusGained", {
    group = utils.get_augroup("WarmStatCacheOnFocus", true),
    callback = function()
      for _, buf in ipairs(registry_instance:get_registry()) do
        if vim.api.nvim_buf_is_valid(buf) then
          local path = vim.api.nvim_buf_get_name(buf)
          if path ~= "" and not path:match("^%a[%w+.-]+://") then
            utils.async_stat(path, function() end)
          end
        end
      end
    end,
  })

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
      utils.async_stat(file_path, function(file_exists)
        if not file_exists then
          actions.close_buffer({ buffer = buf, force = true })
        end
      end)
    end,
  })
end

return autocmds
