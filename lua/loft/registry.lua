local utils = require("loft.utils")
local events = require("loft.events")
local constants = require("loft.constants")

---@class (exact) loft.RegistrySetupOpts
---@field close_invalid_buf_on_switch boolean
---@field smart_order_marked_bufs boolean
---@field smart_order_alt_bufs boolean
---@field enable_smart_order_by_default boolean
---@field enable_recent_marked_mapping boolean
---@field post_leader_marked_mapping string

---@class loft.Registry
---@field private _registry integer[]
---@field private _update_paused boolean
---@field private _update_paused_once boolean
---@field private _is_smart_order_on boolean
---@field opts loft.RegistrySetupOpts
local Registry = {}
Registry.__index = Registry

function Registry:new()
  local instance = setmetatable({}, self)
  instance._registry = {}
  instance._update_paused = false
  instance._update_paused_once = false
  instance._is_smart_order_on = true
  return instance
end

function Registry:get_registry()
  return self._registry
end

--- Update registry to move the given or current buffer to last
---@param buffer? integer
---@private
function Registry:_update(buffer)
  local current_buf = vim.api.nvim_get_current_buf()
  local buf = buffer or current_buf
  local alt_buf = buf == current_buf and vim.fn.bufnr("#") or -1
  if utils.is_floating_window() or self._update_paused then
    self._update_paused_once = false
    return
  end
  if self._update_paused_once then
    self._update_paused_once = false
    return
  end
  local is_buf_valid = utils.is_buffer_valid(buf)
  if not is_buf_valid then
    return
  end
  self:clean()
  local is_buffer_in_registry = false
  local is_alt_buffer_in_registry = false
  local should_smart_order_buf = self._is_smart_order_on
    and (not self.is_buffer_marked(buf) or (self.opts.smart_order_marked_bufs and self.is_buffer_marked(buf)))
  local should_smart_order_alt_buf = self._is_smart_order_on
    and self.opts.smart_order_alt_bufs
    and (not self.is_buffer_marked(alt_buf) or (self.opts.smart_order_marked_bufs and self.is_buffer_marked(alt_buf)))
    and utils.is_buffer_valid(alt_buf)
  for i, b in ipairs(self._registry) do
    if b == buf then
      is_buffer_in_registry = true
      if should_smart_order_buf then
        table.remove(self._registry, i)
      end
      break
    end
  end
  for i, b in ipairs(self._registry) do
    if b == alt_buf then
      is_alt_buffer_in_registry = true
      if should_smart_order_alt_buf then
        table.remove(self._registry, i)
      end
      break
    end
  end
  if is_buffer_in_registry and not should_smart_order_buf then
    return
  end
  if is_alt_buffer_in_registry and should_smart_order_buf then
    table.insert(self._registry, alt_buf)
  end
  table.insert(self._registry, buf)
  self:clean()
  self:on_change()
end

function Registry:pause_update()
  self._update_paused = true
end

function Registry:resume_update()
  self._update_paused = false
end

--- Clean up invalid buffers from registry
function Registry:clean()
  local valid_buffers = {}
  for _, buf in ipairs(self._registry) do
    if utils.is_buffer_valid(buf) then
      table.insert(valid_buffers, buf)
    end
  end

  -- Delete buffers with missing files to prevent them from being switched to and causing issues
  -- This is a safety net in case such buffers are not closed by autocmds
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if utils.buf_has_deleted_file(buf) then
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
  end

  self._registry = utils.merge_distinct(valid_buffers, utils.get_all_valid_buffers())
  self:on_change()
end

--- Get the next buffer in registry
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

--- Get the previous buffer in registry
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

--- Swap given buffer with the previous buffer in registry
---@param buf_idx integer Index of buffer
---@param cyclic? boolean Should swap be cyclic or not i.e from first to last
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
  self:on_change()
end

--- Swap given buffer with the next buffer in registry
---@param buf_idx integer Index of buffer
---@param cyclic? boolean Whether the swap should be cyclic or not i.e from last to first
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
  self:on_change()
end

--- Called on plugin setup
---@param opts loft.RegistrySetupOpts
function Registry:setup(opts)
  self.opts = opts
  self._is_smart_order_on = opts.enable_smart_order_by_default
  vim.api.nvim_create_autocmd("BufEnter", {
    group = utils.get_augroup("UpdateRegistry", true),
    callback = function()
      self:_update()
    end,
  })
  local prevent_update_after_floating_window = utils.greedy_debounce(function()
    if utils.is_floating_window() then
      self._update_paused_once = true
    end
  end, 1000)
  vim.api.nvim_create_autocmd("WinClosed", {
    group = utils.get_augroup("PreventUpdateAfterFloatingWindow", true),
    callback = prevent_update_after_floating_window,
  })
  self:clean()
end

local debounced_keymap_recent_marked_buffers = utils.debounce(
  ---@param self loft.Registry
  function(self)
    self:keymap_recent_marked_buffers()
  end,
  800
)

--- Store a given buffer's mark state in b:scoped variables
---@param buffer integer
---@param mark_state boolean
---@private
function Registry:_mark_buffer(buffer, mark_state)
  if mark_state then
    vim.api.nvim_buf_set_var(buffer, constants.MARK_STATE_ID, mark_state)
  else
    pcall(vim.api.nvim_buf_del_var, buffer, constants.MARK_STATE_ID)
  end
  events.buffer_mark(buffer, self.is_buffer_marked(buffer))
  if self.opts.enable_recent_marked_mapping then
    debounced_keymap_recent_marked_buffers(self)
  end
end

--- Check if a given buffer is marked
---@param buffer integer
function Registry.is_buffer_marked(buffer)
  local ok, mark_state = pcall(vim.api.nvim_buf_get_var, buffer, constants.MARK_STATE_ID)
  if ok and mark_state then
    return mark_state
  end
  return false
end

--- Toggle the mark state of a given buffer
---@param buffer integer
---@return boolean: New mark state of given buffer
function Registry:toggle_mark_buffer(buffer)
  self:_mark_buffer(buffer, not self.is_buffer_marked(buffer))
  return self.is_buffer_marked(buffer)
end

--- Get the next or prev marked buffer in registry
---@param direction  'next'|'prev'
---@param buffer?  integer
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
    if self.is_buffer_marked(buf) then
      return buf
    end
  end
  return nil
end

---Get the keymap index for the given or current marked buffer
---@param buffer?  integer
function Registry:get_marked_buffer_keymap_index(buffer)
  local buf = buffer or vim.api.nvim_get_current_buf()
  local marked_buffers = self:_get_marked_buffers()
  local count = 1
  for i = #marked_buffers, math.max(1, #marked_buffers - 8), -1 do
    if marked_buffers[i] == buf then
      return count
    end
    count = count + 1
  end
  return nil
end

function Registry:is_smart_order_on()
  return self._is_smart_order_on
end

---@return boolean: New state of smart order
function Registry:toggle_smart_order()
  self._is_smart_order_on = not self._is_smart_order_on
  events.smart_order_toggle(self._is_smart_order_on)
  return self._is_smart_order_on
end

---@return integer[]: Marked buffers
---@private
function Registry:_get_marked_buffers()
  local marked_buffers = {}
  for _, buf in ipairs(self._registry) do
    if self.is_buffer_marked(buf) then
      table.insert(marked_buffers, buf)
    end
  end
  return marked_buffers
end

--- Set navigation keymaps for the 9 most recent marked buffers
function Registry:keymap_recent_marked_buffers()
  if not self.opts.enable_recent_marked_mapping then
    return
  end
  local pre_key = "<leader>" .. self.opts.post_leader_marked_mapping
  local marked_buffers = self:_get_marked_buffers()
  for i = 1, 9 do
    local key = pre_key .. i
    pcall(vim.keymap.del, "n", key)
  end
  local count = 1
  for i = #marked_buffers, math.max(1, #marked_buffers - 8), -1 do
    local buf = marked_buffers[i]
    if utils.is_buffer_valid(buf) then
      local buffer = vim.fn.getbufinfo(buf)[1]
      local bufname = buffer.name ~= "" and buffer.name or "[No Name]"
      local relative_path = vim.fn.fnamemodify(bufname, ":.")
      local key = pre_key .. count
      vim.keymap.set("n", key, function()
        self:pause_update()
        vim.api.nvim_set_current_buf(buf)
        pcall(vim.api.nvim_set_current_buf, buf)
        self:resume_update()
      end, { desc = "⨳⨳ ➺ " .. relative_path, noremap = true, silent = true })
    end
    count = count + 1
  end
end

--- Called at the end of all methods that mutate registry
function Registry:on_change()
  if self.opts.enable_recent_marked_mapping then
    debounced_keymap_recent_marked_buffers(self)
  end
end

return Registry:new()
