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

---Check if the given or current or window is a floating
utils.get_all_valid_buffers = function()
  ---@type integer[]
  local all_valid_buffers = {}
  local buffers = vim.api.nvim_list_bufs()
  for _, buf in ipairs(buffers) do
    if utils.is_buffer_valid(buf) then
      table.insert(all_valid_buffers, buf)
    end
  end
  return all_valid_buffers
end

---Merge two tables (arrays of integers) and return a final table with distinct values
---@param table1 integer[]
---@param table2 integer[]
---@return integer[]
utils.merge_distinct = function(table1, table2)
  local result = {}
  local seen = {}
  for _, v in ipairs(table1) do
    if not seen[v] then
      table.insert(result, v)
      seen[v] = true
    end
  end
  for _, v in ipairs(table2) do
    if not seen[v] then
      table.insert(result, v)
      seen[v] = true
    end
  end
  return result
end

---Make buffer modifiable or not
---@param buf integer
---@param modifiable boolean
utils.buffer_modifiable = function(buf, modifiable)
  vim.api.nvim_set_option_value("modifiable", modifiable, { buf })
end

---Check if buffer exists or not
---@param buf integer|nil
utils.buffer_exists = function(buf)
  return (buf and vim.api.nvim_buf_is_valid(buf)) or false
end

---Check if window exists or not
---@param win integer|nil
utils.window_exists = function(win)
  return (win and vim.api.nvim_win_is_valid(win)) or false
end

return utils
