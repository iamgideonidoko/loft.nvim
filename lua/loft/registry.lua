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
  for _, buf in ipairs(self._registry) do
    if utils.is_buffer_valid(buf) then
      table.insert(valid_buffers, buf)
    end
  end
  self._registry = utils.merge_distinct(valid_buffers, utils.get_all_valid_buffers())
end

---Get the next buffer in registry
function Registry:get_next_buffer()
  local current_buf = vim.api.nvim_get_current_buf()
  ---@type integer|nil
  local current_index
  for i, buf in ipairs(self._registry) do
    if buf == current_buf then
      current_index = i
      break
    end
  end
  if current_index == nil then
    return
  end
  -- Calculate the next index in a circular manner
  local next_index = (current_index % #self._registry) + 1
  local next_buf = self._registry[next_index]
  return next_buf
end

---Get the previous buffer in registry
function Registry:get_prev_buffer()
  local current_buf = vim.api.nvim_get_current_buf()
  ---@type integer|nil
  local current_index
  for i, buf in ipairs(self._registry) do
    if buf == current_buf then
      current_index = i
      break
    end
  end
  if current_index == nil then
    return
  end
  -- Calculate the previous index in a circular manner
  local prev_index = current_index - 1
  if prev_index < 1 then
    prev_index = #self._registry
  end
  local prev_buf = self._registry[prev_index]
  return prev_buf
end

return Registry:new()
