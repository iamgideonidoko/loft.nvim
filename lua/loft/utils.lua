local constants = require("loft.constants")

local utils = {}

utils.is_dev = function()
  return require("lazy.core.config").plugins[constants.PLUGIN_NAME].dev
end

---Check if the given or current or window is a floating
---@param window number?
utils.is_floating_window = function(window)
  local win_id = window or vim.api.nvim_get_current_win()
  local win_config = vim.api.nvim_win_get_config(win_id)
  return win_config.relative ~= ""
end

---Check if the given buffer is valid (listed)
---@param buf number
utils.is_buffer_valid = function(buf)
  return 1 == vim.fn.buflisted(buf)
end

return utils
