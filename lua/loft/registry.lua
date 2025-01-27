local utils = require("loft.utils")
local events = require("loft.events")
local constants = require("loft.constants")

---@class loft.Registry
---@field private _registry integer[]
---@field private _update_paused boolean
---@field private _update_paused_once boolean
---@field private _is_telescope_item_selected boolean
---@field private _is_smart_order_on boolean
---@field close_invalid_buf_on_switch boolean
local Registry = {}
Registry.__index = Registry

function Registry:new()
  local instance = setmetatable({}, self)
  instance._registry = {}
  instance._update_paused = false
  instance._update_paused_once = false
  instance._is_telescope_item_selected = false
  instance._is_smart_order_on = true
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
  local is_buffer_in_registry = false
  for i, b in ipairs(self._registry) do
    if b == buf then
      is_buffer_in_registry = true
      if self._is_smart_order_on then
        table.remove(self._registry, i)
      end
      break
    end
  end
  if not utils.is_buffer_valid(buf) then
    return
  end
  if is_buffer_in_registry and not self._is_smart_order_on then
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
  -- Clean up buffers with missing files
  local current_buf = vim.api.nvim_get_current_buf()
  for _, buf in ipairs(self._registry) do
    if utils.buf_has_deleted_file(buf) and buf ~= current_buf then
      -- Skip the current buffer since it's safely handled by autocmd (like switching to next. see lua/loft/autocmds.lua)
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
  end
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
---@param opts  { track_telescope_select: boolean, close_invalid_buf_on_switch: boolean }
function Registry:setup(opts)
  self.close_invalid_buf_on_switch = opts.close_invalid_buf_on_switch
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
  if opts.track_telescope_select then
    self:_overwrite_telescope_select()
  end
  self:clean()
end

---Safely overwrite telescope's select to track selection
---@private
function Registry:_overwrite_telescope_select()
  local action_set_ok, action_set = pcall(require, "telescope.actions.set")
  local mt_ok, mt = pcall(require, "telescope.actions.mt")
  if not action_set_ok or not mt_ok then
    return
  end
  local original_select = action_set.select
  ---@diagnostic disable-next-line: duplicate-set-field
  action_set.select = function(prompt_bufnr, type)
    self._is_telescope_item_selected = true
    original_select(prompt_bufnr, type)
  end
  local action_set_clone = vim.tbl_deep_extend("force", {}, action_set)
  action_set_clone = mt.transform_mod(action_set_clone)
  action_set.select = action_set_clone.select
end

---Store a given buffer's mark state in b:scoped variables
---@param buffer integer
---@param mark_state boolean
---@private
function Registry:_mark_buffer(buffer, mark_state)
  if mark_state then
    vim.api.nvim_buf_set_var(buffer, constants.MARK_STATE_ID, mark_state)
  else
    pcall(vim.api.nvim_buf_del_var, buffer, constants.MARK_STATE_ID)
  end
  events.buffer_mark(buffer, self:is_buffer_marked(buffer))
end

---Check if a given buffer is marked
---@param buffer integer
function Registry:is_buffer_marked(buffer)
  local ok, mark_state = pcall(vim.api.nvim_buf_get_var, buffer, constants.MARK_STATE_ID)
  if ok and mark_state then
    return mark_state
  end
  return false
end

---Toggle the mark state of a given buffer
---@param buffer integer
---@return boolean: New mark state of given buffer
function Registry:toggle_mark_buffer(buffer)
  self:_mark_buffer(buffer, not self:is_buffer_marked(buffer))
  return self:is_buffer_marked(buffer)
end

---Get the next or prev marked buffer in registry
---@param direction  'next'|'prev'
---@param buffer  integer?
function Registry:get_marked_buffer(direction, buffer)
  local current_buf = buffer or vim.api.nvim_get_current_buf()
  local current_index = nil
  for i, buf in ipairs(self._registry) do
    if buf == current_buf then
      current_index = i
      break
    end
  end
  local count = #self._registry
  for i = 1, count do
    local j = i
    if direction == "prev" then
      j = -1 * i
    end
    local index = ((current_index or 1) + j - 1) % count + 1
    local buf = self._registry[index]
    if self:is_buffer_marked(buf) then
      return buf
    end
  end
  return nil
end

function Registry:is_smart_order_on()
  return self._is_smart_order_on
end

---@return boolean: New state of smart order
function Registry:toggle_smart_order()
  self._is_smart_order_on = not self._is_smart_order_on
  return self._is_smart_order_on
end

return Registry:new()
