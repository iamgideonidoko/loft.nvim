local constants = require("loft.constants")

local utils = {}

utils.is_dev = function()
  local lazy_config_ok, lazy_config = pcall(require, "lazy.core.config")
  if not lazy_config_ok then
    return false
  end
  return lazy_config.plugins[constants.PLUGIN_NAME].dev
end

--- Check if the given or current or window is a floating
---@param window? number
utils.is_floating_window = function(window)
  local win_id = window or vim.api.nvim_get_current_win()
  local win_config = vim.api.nvim_win_get_config(win_id)
  return win_config.relative ~= ""
end

--- Check if the given buffer is valid (listed)
---@param buf number
utils.is_buffer_valid = function(buf)
  return 1 == vim.fn.buflisted(buf) and not utils.buf_has_deleted_file(buf)
end

--- Check if the given or current or window is a floating
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

--- Merge two tables (arrays of integers) and return a final table with distinct values
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

--- Make buffer modifiable or not
---@param buf integer
---@param modifiable boolean
utils.buffer_modifiable = function(buf, modifiable)
  vim.api.nvim_set_option_value("modifiable", modifiable, { buf = buf })
end

--- Check if buffer exists or not
---@param buf integer|nil
utils.buffer_exists = function(buf)
  return (buf and vim.api.nvim_buf_is_valid(buf)) or false
end

--- Check if window exists or not
---@param win integer|nil
utils.window_exists = function(win)
  return (win and vim.api.nvim_win_is_valid(win)) or false
end

--- Get the index of a given item in an table (array)
---@param table any[]
---@param item any
utils.get_index = function(table, item)
  for index, value in ipairs(table) do
    if value == item then
      return index
    end
  end
  return nil
end

--- Check if a table (array) includes a given value
---@param table any[]
---@param value any
utils.table_includes = function(table, value)
  for _, buf in ipairs(table) do
    if buf == value then
      return true
    end
  end
  return false
end

--- Get safe autocommand group
---@param name string
---@param clear boolean
utils.get_augroup = function(name, clear)
  return vim.api.nvim_create_augroup(constants.DISPLAY_NAME .. name, { clear = clear })
end

--- Ensure that a function is greedily called only once in a given time frame
---@param func function
---@param timeout number Time in milliseconds
utils.greedy_debounce = function(func, timeout)
  ---@diagnostic disable-next-line: redefined-local
  local last_closed_time = 0
  return function(...)
    local current_time = vim.fn.reltimefloat(vim.fn.reltime()) * 1000
    if current_time - last_closed_time > timeout then
      last_closed_time = current_time
      func(...)
    end
  end
end

--- Check if the given or current buffer has a deleted or missing file
---@param buffer? integer
utils.buf_has_deleted_file = function(buffer)
  local buf = buffer or vim.api.nvim_get_current_buf()
  local ok, buftype = pcall(vim.api.nvim_get_option_value, "buftype", { buf = buf })
  if not ok then
    return false
  end
  local file_path = vim.api.nvim_buf_get_name(buf)
  local stat = vim.loop.fs_stat(file_path)
  return not (
    buftype ~= ""
    or file_path == ""
    or stat
    or vim.fn.filereadable(file_path) == 1
    or 0 == vim.fn.buflisted(buf)
  )
end

--- Ensure that a function is called only once in a given time frame
---@param func function
---@param timeout number Time in milliseconds
utils.debounce = function(func, timeout)
  local timer = nil
  return function(...)
    local args = { ... }
    if timer then
      vim.loop.timer_stop(timer)
    else
      timer = vim.loop.new_timer()
    end
    timer:start(timeout, 0, function()
      vim.schedule(function()
        func(unpack(args))
      end)
    end)
  end
end

--- Get the major, minor and patch version of the current Neovim instance
---@return integer major
---@return integer minor
---@return integer patch
utils.get_nvim_version = function()
  local version = vim.version()
  return version.major, version.minor, version.patch
end

return utils
