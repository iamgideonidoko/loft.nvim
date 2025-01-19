local utils = require("loft.utils")

---@class loft.Registry
---@field private _registry integer[]
---@field private _update_paused boolean
---@field private _update_paused_once boolean
local Registry = {}
Registry.__index = Registry

function Registry:new()
  local instance = setmetatable({}, self)
  instance._registry = {}
  instance._update_paused = false
  instance._update_paused_once = false
  return instance
end

function Registry:get_registry()
  return self._registry
end

---Update registry to move the given or current buffer to last
---@param buffer integer?
function Registry:update(buffer)
  local buf = buffer or vim.api.nvim_get_current_buf()
  if utils.is_floating_window() or self._update_paused then
    return
  end
  if self._update_paused_once then
    self._update_paused_once = false
    return
  end
  for i, b in ipairs(self._registry) do
    if b == buf then
      table.remove(self._registry, i)
      break
    end
  end
  if not utils.is_buffer_valid(buf) then
    return
  end
  table.insert(self._registry, buf)
end

function Registry:pause_update()
  self._update_paused = true
end

function Registry:resume_update()
  self._update_paused = false
end

function Registry:pause_update_one()
  self._update_paused_once = true
end

---Clean up invalid buffers from registry
function Registry:clean()
  local valid_buffers = {}
  local current_buf = vim.api.nvim_get_current_buf()
  local is_current_buf_in_registry = false
  for _, buf in ipairs(self._registry) do
    if utils.is_buffer_valid(buf) then
      table.insert(valid_buffers, buf)
      if current_buf == buf then
        is_current_buf_in_registry = true
      end
    end
  end
  if utils.is_buffer_valid(current_buf) and not is_current_buf_in_registry then
    table.insert(valid_buffers, current_buf)
  end
  self._registry = valid_buffers
end

return Registry:new()
