local actions = require("loft.actions")
local utils = require("loft.utils")
local autocmds = {}

autocmds.setup = function()
  vim.api.nvim_create_autocmd({ "BufEnter", "FocusGained" }, {
    group = utils.get_augroup("DeleteMissingFileBuffer", true),
    callback = function()
      local buf = vim.api.nvim_get_current_buf()
      vim.schedule(function()
        if utils.buf_has_deleted_file(buf) then
          actions.close_buffer({ buf = buf, force = true })
        end
      end)
    end,
  })
end

return autocmds
