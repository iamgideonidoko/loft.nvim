local utils = require("loft.utils")

---@class loft.Registry
---@field private _registry integer[]
---@field private _update_paused boolean
---@field private _update_paused_once boolean
---@field private _is_telescope_item_selected boolean
local Registry = {}
Registry.__index = Registry

function Registry:new()
  local instance = setmetatable({}, self)
  instance._registry = {}
  instance._update_paused = false
  instance._update_paused_once = false
  instance._is_telescope_item_selected = false
  return instance
end

function Registry:get_registry()
  return self._registry
end

---Update registry to move the given or current buffer to last
---@param buffer integer?
---@private
function Registry:_update(buffer)
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

---Swap given buffer with the previous buffer in registry
---@param buf_idx integer: Index of buffer
---@param cyclic boolean?: Should swap be cyclic or not i.e from first to last
function Registry:move_buffer_up(buf_idx, cyclic)
  if buf_idx > 1 then
    local buffer = self._registry[buf_idx]
    self._registry[buf_idx] = self._registry[buf_idx - 1]
    self._registry[buf_idx - 1] = buffer
  elseif cyclic then
    local first_buffer = self._registry[1]
    table.remove(self._registry, 1)
    table.insert(self._registry, first_buffer)
  end
end

---Swap given buffer with the next buffer in registry
---@param buf_idx integer: Index of buffer
---@param cyclic boolean?: Whether the swap should be cyclic or not i.e from last to first
function Registry:move_buffer_down(buf_idx, cyclic)
  if buf_idx < #self._registry then
    local buffer = self._registry[buf_idx]
    self._registry[buf_idx] = self._registry[buf_idx + 1]
    self._registry[buf_idx + 1] = buffer
  elseif cyclic then
    local last_buffer = self._registry[#self._registry]
    table.remove(self._registry)
    table.insert(self._registry, 1, last_buffer)
  end
end

---Called on plugin setup
function Registry:setup()
  vim.api.nvim_create_autocmd("BufEnter", {
    group = utils.get_augroup("UpdateRegistry", true),
    callback = function()
      self:_update()
    end,
  })
  local prevent_update_after_floating_window = utils.safe_debounce(function()
    if utils.is_floating_window() then
      if self._is_telescope_item_selected then
        self._is_telescope_item_selected = false
        self._update_paused_once = false
      else
        self._update_paused_once = true
      end
    end
  end, 1000)
  vim.api.nvim_create_autocmd("WinClosed", {
    group = utils.get_augroup("PreventUpdateAfterFloatingWindow", true),
    callback = prevent_update_after_floating_window,
  })
  self:_overwrite_telescope_select()
  self:clean()
end

---@private
function Registry:_overwrite_telescope_select()
  local ok, action_set = pcall(require, "telescope.actions.set")
  if not ok then
    return
  end
  local original_select = action_set.select
  ---@diagnostic disable-next-line: duplicate-set-field
  action_set.select = function(prompt_bufnr, type)
    self._is_telescope_item_selected = true
    original_select(prompt_bufnr, type)
  end
end

return Registry:new()
