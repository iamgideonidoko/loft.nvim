---@diagnostic disable: assign-type-mismatch
local registry_instance = require("loft.registry")
local utils = require("loft.utils")

---@class (exact) loft.Action
---@field desc string
---@field func function

---@type table<string, loft.Action>
local actions = {}

---Delete a buffer without closing splits
---@type fun(opts: { force: boolean?, buffer: integer? }?)
actions.close_buffer = {
  desc = "Close buffer",
  ---@param opts { force: boolean?, buffer: integer? }?
  func = function(opts)
    opts = opts or {}
    local current_buf = opts.buffer or vim.api.nvim_get_current_buf()
    if not opts.force and vim.api.nvim_get_option_value("modified", { buf = current_buf }) then
      return vim.api.nvim_err_writeln("Buffer is modified. Force required.")
    end
    if not opts.force and vim.api.nvim_get_option_value("buftype", { buf = current_buf }) == "terminal" then
      return vim.api.nvim_err_writeln("Buffer is a terminal. Force required.")
    end
    registry_instance:clean()
    local alt_buf = vim.fn.bufnr("#")
    local next_buf = nil
    local found_current = false
    for _, buf in ipairs(registry_instance:get_registry()) do
      if found_current then
        next_buf = buf
        break
      end
      if buf == current_buf then
        found_current = true
      end
    end
    if #registry_instance:get_registry() > 1 and not next_buf then
      -- The next valid buffer is likely the first
      next_buf = registry_instance:get_registry()[1]
    end
    registry_instance:pause_update()
    -- Replace current buffer with alt or next or empty buffer in all windows
    for _, win in ipairs(vim.fn.win_findbuf(current_buf)) do
      if utils.is_buffer_valid(alt_buf) then
        vim.api.nvim_win_set_buf(win, alt_buf)
      elseif next_buf then
        vim.api.nvim_win_set_buf(win, next_buf)
      else
        vim.api.nvim_win_set_buf(win, vim.api.nvim_create_buf(false, true))
      end
    end
    pcall(vim.api.nvim_buf_delete, current_buf, { force = opts.force })
    registry_instance:resume_update()
    registry_instance:clean()
  end,
}

---Navigate to the next buffer in registry
---@type fun()
actions.switch_to_next_buffer = {
  desc = "Switch to next buffer",
  func = function()
    registry_instance:clean()
    local next_buf = registry_instance:get_next_buffer()
    if next_buf == nil then
      local current_buf = vim.api.nvim_get_current_buf()
      if not utils.is_buffer_valid(current_buf) and registry_instance.close_invalid_buf_on_switch then
        actions.close_buffer({ force = true })
      end
      return
    end
    registry_instance:pause_update()
    vim.api.nvim_set_current_buf(next_buf)
    registry_instance:resume_update()
  end,
}

---Navigate to the previous buffer in registry
---@type fun()
actions.switch_to_prev_buffer = {
  desc = "Switch to previous buffer",
  func = function()
    registry_instance:clean()
    local prev_buf = registry_instance:get_prev_buffer()
    if prev_buf == nil then
      local current_buf = vim.api.nvim_get_current_buf()
      if not utils.is_buffer_valid(current_buf) and registry_instance.close_invalid_buf_on_switch then
        actions.close_buffer({ force = true })
      end
      return
    end
    registry_instance:pause_update()
    vim.api.nvim_set_current_buf(prev_buf)
    registry_instance:resume_update()
  end,
}

---@type fun()
actions.open_loft = {
  desc = "Open Loft",
  func = function()
    require("loft.ui"):open()
  end,
}

---Navigate to the next marked buffer in registry
---@type fun()
actions.switch_to_next_marked_buffer = {
  desc = "Switch to next marked buffer",
  func = function()
    registry_instance:clean()
    local next_marked_buf = registry_instance:get_marked_buffer("next")
    if next_marked_buf == nil then
      return
    end
    registry_instance:pause_update()
    vim.api.nvim_set_current_buf(next_marked_buf)
    registry_instance:resume_update()
  end,
}

---Navigate to the prev marked buffer in registry
---@type fun()
actions.switch_to_prev_marked_buffer = {
  desc = "Switch to previous marked buffer",
  func = function()
    registry_instance:clean()
    local prev_marked_buf = registry_instance:get_marked_buffer("prev")
    if prev_marked_buf == nil then
      return
    end
    registry_instance:pause_update()
    vim.api.nvim_set_current_buf(prev_marked_buf)
    registry_instance:resume_update()
  end,
}

---Toggle mark the current buffer
---@type fun(opts: { notify: boolean? }?)
actions.toggle_mark_current_buffer = {
  desc = "Toggle mark current buffer",
  ---@param opts { notify: boolean? }?
  func = function(opts)
    opts = opts or {}
    if opts.notify == nil then
      opts.notify = true -- Default to true
    end
    local current_buf = vim.api.nvim_get_current_buf()
    if utils.is_buffer_valid(current_buf) then
      local new_mark_state = registry_instance:toggle_mark_buffer(current_buf)
      if opts.notify then
        if new_mark_state then
          vim.notify("Marked", vim.log.levels.INFO)
        else
          vim.notify("Unmarked", vim.log.levels.INFO)
        end
      end
    end
  end,
}

---Toggle the smart order status
---@type fun(opts: { notify: boolean? }?)
actions.toggle_smart_order = {
  desc = "Toggle Smart Order ON and OFF",
  ---@type fun(opts: { notify: boolean? }?)
  func = function(opts)
    opts = opts or {}
    if opts.notify == nil then
      opts.notify = true
    end
    local ui_instance = require("loft.ui")
    local new_state = ui_instance:toggle_smart_order()
    if not ui_instance:is_open() and opts.notify then
      if new_state then
        vim.notify("Smart Order is ON", vim.log.levels.INFO)
      else
        vim.notify("Smart Order is OFF", vim.log.levels.INFO)
      end
    end
  end,
}

for _, action in pairs(actions) do
  setmetatable(action, {
    __call = function(_, ...)
      action.func(...)
    end,
  })
end

return actions
